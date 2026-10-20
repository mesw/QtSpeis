#include "tvprogramfetcher.h"
#include "dayplanmodel.h"

#include <QRegularExpression>
#include <QDate>
#include <QDateTime>
#include <QUrl>
#include <QSet>
#include <QDebug>
#include <algorithm>

namespace {

QString decodeHtmlEntities(QString str)
{
    str.replace(QStringLiteral("&auml;"), QStringLiteral("ä"))
       .replace(QStringLiteral("&Auml;"), QStringLiteral("Ä"))
       .replace(QStringLiteral("&ouml;"), QStringLiteral("ö"))
       .replace(QStringLiteral("&Ouml;"), QStringLiteral("Ö"))
       .replace(QStringLiteral("&uuml;"), QStringLiteral("ü"))
       .replace(QStringLiteral("&Uuml;"), QStringLiteral("Ü"))
       .replace(QStringLiteral("&szlig;"), QStringLiteral("ß"))
       .replace(QStringLiteral("&quot;"), QStringLiteral("\""))
       .replace(QStringLiteral("&apos;"), QStringLiteral("'"))
       .replace(QStringLiteral("&#039;"), QStringLiteral("'"))
       .replace(QStringLiteral("&nbsp;"), QStringLiteral(" "))
       .replace(QStringLiteral("&ndash;"), QStringLiteral("–"))
       .replace(QStringLiteral("&mdash;"), QStringLiteral("—"))
       .replace(QStringLiteral("&amp;"), QStringLiteral("&"));
    return str;
}

} // anonymous namespace

TvProgramFetcher::TvProgramFetcher(QObject *parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
{
}

TvProgramFetcher::~TvProgramFetcher()
{
    abortAllRequests();
}

void TvProgramFetcher::setChannel(const QString &channel)
{
    if (m_channel != channel) {
        m_channel = channel.trimmed().toLower();
        emit channelChanged();
    }
}

void TvProgramFetcher::setDaysToFetch(int days)
{
    if (days > 0 && m_daysToFetch != days) {
        m_daysToFetch = days;
        emit daysToFetchChanged();
    }
}

void TvProgramFetcher::setTargetModel(DayPlanModel *model)
{
    if (m_targetModel != model) {
        m_targetModel = model;
        emit targetModelChanged();
    }
}

void TvProgramFetcher::abortAllRequests()
{
    if (m_initialReply) {
        m_initialReply->abort();
        m_initialReply->deleteLater();
        m_initialReply = nullptr;
    }
    for (auto it = m_pendingReplies.begin(); it != m_pendingReplies.end(); ++it) {
        if (it.key()) {
            it.key()->abort();
            it.key()->deleteLater();
        }
    }
    m_pendingReplies.clear();
}

void TvProgramFetcher::cancel()
{
    if (m_isLoading) {
        abortAllRequests();
        m_isLoading = false;
        m_statusMessage = QStringLiteral("Fetch canceled");
        emit isLoadingChanged();
        emit statusMessageChanged();
        emit fetchFinished(false, m_statusMessage);
    }
}

void TvProgramFetcher::fetchProgram(const QString &channel, int days)
{
    if (!channel.trimmed().isEmpty()) {
        setChannel(channel);
    }
    if (days > 0) {
        setDaysToFetch(days);
    }

    if (m_isLoading) {
        abortAllRequests();
    }

    m_isLoading = true;
    m_dayHtmls.clear();
    m_statusMessage = QStringLiteral("Connecting to tv.orf.at for %1...").arg(m_channel.toUpper());
    emit isLoadingChanged();
    emit statusMessageChanged();
    emit fetchStarted();

    QString urlStr = QStringLiteral("https://tv.orf.at/program/%1/").arg(m_channel);
    QUrl targetUrl(urlStr);
    QNetworkRequest request(targetUrl);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64) QtSpeis/1.0"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    m_initialReply = m_nam->get(request);
    connect(m_initialReply, &QNetworkReply::finished, this, &TvProgramFetcher::onInitialPageReplyFinished);
}

void TvProgramFetcher::onInitialPageReplyFinished()
{
    if (!m_initialReply) {
        return;
    }

    if (m_initialReply->error() != QNetworkReply::NoError) {
        m_statusMessage = QStringLiteral("Error: %1").arg(m_initialReply->errorString());
        m_isLoading = false;
        emit isLoadingChanged();
        emit statusMessageChanged();
        emit fetchFinished(false, m_statusMessage);
        m_initialReply->deleteLater();
        m_initialReply = nullptr;
        return;
    }

    QString initialHtml = QString::fromUtf8(m_initialReply->readAll());
    m_initialReply->deleteLater();
    m_initialReply = nullptr;

    m_dayHtmls[0] = initialHtml;

    // Parse navigation links from #day-navigation: <li ... data-ds-day-index="(-?\d+)" ...> ... href="([^"]+)"
    QRegularExpression navRegex(QStringLiteral("<li[^>]*data-ds-day-index=\"(-?\\d+)\"[^>]*>\\s*<a[^>]*href=\"([^\"]+)\""));
    auto it = navRegex.globalMatch(initialHtml);
    QMap<int, QString> dayLinks;
    while (it.hasNext()) {
        auto match = it.next();
        int idx = match.captured(1).toInt();
        QString href = match.captured(2);
        dayLinks[idx] = href;
    }

    QList<int> neededIndices;
    // Day -1 (yesterday) provides late-night broadcasts from midnight to 06:00 today
    if (dayLinks.contains(-1)) {
        neededIndices.append(-1);
    }
    // Days 1 up to m_daysToFetch - 1
    for (int i = 1; i < m_daysToFetch; ++i) {
        if (dayLinks.contains(i)) {
            neededIndices.append(i);
        }
    }

    if (neededIndices.isEmpty()) {
        finalizeParsing();
        return;
    }

    m_totalDaysToFetch = neededIndices.size() + 1; // +1 for Day 0 already received
    m_statusMessage = QStringLiteral("Fetching %1 schedule (1/%2 days)...").arg(m_channel.toUpper()).arg(m_totalDaysToFetch);
    emit statusMessageChanged();

    for (int idx : neededIndices) {
        QString href = dayLinks[idx];
        QString subUrl = href.startsWith('/') ? (QStringLiteral("https://tv.orf.at") + href) : href;
        QUrl targetUrl(subUrl);
        QNetworkRequest req(targetUrl);
        req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Mozilla/5.0 (Windows NT 10.0; Win64; x64) QtSpeis/1.0"));
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

        QNetworkReply *reply = m_nam->get(req);
        m_pendingReplies[reply] = idx;
        connect(reply, &QNetworkReply::finished, this, &TvProgramFetcher::onSubDayReplyFinished);
    }
}

void TvProgramFetcher::onSubDayReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) {
        return;
    }

    int dayIdx = m_pendingReplies.value(reply, -999);
    m_pendingReplies.remove(reply);

    if (reply->error() == QNetworkReply::NoError) {
        m_dayHtmls[dayIdx] = QString::fromUtf8(reply->readAll());
    } else {
        qWarning() << "Failed to fetch schedule for day index" << dayIdx << ":" << reply->errorString();
    }
    reply->deleteLater();

    int completed = m_totalDaysToFetch - m_pendingReplies.size();
    m_statusMessage = QStringLiteral("Fetching %1 schedule (%2/%3 days)...").arg(m_channel.toUpper()).arg(completed).arg(m_totalDaysToFetch);
    emit statusMessageChanged();

    if (m_pendingReplies.isEmpty()) {
        finalizeParsing();
    }
}

void TvProgramFetcher::finalizeParsing()
{
    m_isLoading = false;
    emit isLoadingChanged();

    QList<int> sortedDayKeys = m_dayHtmls.keys();
    std::sort(sortedDayKeys.begin(), sortedDayKeys.end());

    // Determine reference today date from Day 0 items, fallback to QDate::currentDate()
    QDate today = QDate::currentDate();
    if (m_dayHtmls.contains(0)) {
        QList<BroadcastItem> day0Items = extractBroadcastsFromHtml(m_dayHtmls.value(0));
        for (const auto &it : day0Items) {
            if (it.itemDate.isValid()) {
                today = it.itemDate;
                break;
            }
        }
    }
    if (!today.isValid()) {
        today = QDate::currentDate();
    }

    QDate maxDate = today.addDays(m_daysToFetch);

    QList<BroadcastItem> allItems;
    QSet<QString> seenStarts;

    for (int dKey : sortedDayKeys) {
        QString html = m_dayHtmls.value(dKey);
        QList<BroadcastItem> pageItems = extractBroadcastsFromHtml(html);
        for (const BroadcastItem &it : pageItems) {
            if (!it.itemDate.isValid()) continue;
            // Only keep items within our target date window [today, today + daysToFetch)
            if (it.itemDate < today || it.itemDate >= maxDate) continue;
            if (seenStarts.contains(it.startIso)) continue;

            seenStarts.insert(it.startIso);
            allItems.append(it);
        }
    }

    if (allItems.isEmpty()) {
        m_statusMessage = QStringLiteral("No broadcast items found for %1").arg(m_channel.toUpper());
        emit statusMessageChanged();
        emit fetchFinished(false, m_statusMessage);
        return;
    }

    // Sort strictly chronologically by startIso
    std::sort(allItems.begin(), allItems.end(), [](const BroadcastItem &a, const BroadcastItem &b) {
        return a.startIso < b.startIso;
    });

    // Build unified YAML
    QString yaml;
    yaml.append(QStringLiteral("version: \"1.0\"\n"));
    yaml.append(QStringLiteral("title: \"%1 TV-Programm (%2 - %3)\"\n\n")
        .arg(m_channel.toUpper(),
             today.toString(QStringLiteral("dd.MM.yyyy")),
             today.addDays(m_daysToFetch - 1).toString(QStringLiteral("dd.MM.yyyy"))));
    yaml.append(QStringLiteral("plan:\n"));

    for (const BroadcastItem &it : allItems) {
        yaml.append(QStringLiteral("  - title: \"%1\"\n").arg(it.title));
        yaml.append(QStringLiteral("    start: \"%1\"\n").arg(it.startClock));
        yaml.append(QStringLiteral("    end: \"%1\"\n").arg(it.endClock));
        yaml.append(QStringLiteral("    icon: %1\n").arg(it.icon));
        yaml.append(QStringLiteral("    color: \"%1\"\n").arg(it.color));
        yaml.append(QStringLiteral("    day: %1\n").arg(it.dayOfWeek));
        if (!it.description.isEmpty()) {
            yaml.append(QStringLiteral("    description: \"%1\"\n").arg(it.description));
        }
        yaml.append('\n');
    }

    m_lastItemCount = allItems.size();
    m_lastFetchedYaml = yaml;
    emit lastItemCountChanged();
    emit lastFetchedYamlChanged();

    m_statusMessage = QStringLiteral("Loaded %1 broadcasts across %2 days for %3")
        .arg(allItems.size())
        .arg(m_daysToFetch)
        .arg(m_channel.toUpper());
    emit statusMessageChanged();

    if (m_targetModel) {
        m_targetModel->loadYaml(yaml);
    }

    emit yamlReady(yaml);
    emit fetchFinished(true, m_statusMessage);
}

QList<TvProgramFetcher::BroadcastItem> TvProgramFetcher::extractBroadcastsFromHtml(const QString &html) const
{
    QList<BroadcastItem> result;

    // Pattern to find opening <li ... class="...broadcast..." ...>
    QRegularExpression liRegex(QStringLiteral("<li\\b[^>]*\\bclass=\"[^\"]*\\bbroadcast\\b[^\"]*\"[^>]*>"), QRegularExpression::CaseInsensitiveOption);

    auto matchIter = liRegex.globalMatch(html);
    QList<int> liPositions;
    while (matchIter.hasNext()) {
        auto m = matchIter.next();
        liPositions.append(m.capturedStart());
    }

    if (liPositions.isEmpty()) {
        return result;
    }

    QRegularExpression startTimeRegex(QStringLiteral("data-start-time=\"([^\"]+)\""));
    QRegularExpression endTimeRegex(QStringLiteral("data-end-time=\"([^\"]+)\""));
    QRegularExpression seriesRegex(QStringLiteral("<div\\s+class=\"series-title\"[^>]*>(.*?)</div>"), QRegularExpression::DotMatchesEverythingOption);
    QRegularExpression episodeRegex(QStringLiteral("<div\\s+class=\"episode-title\"[^>]*>(.*?)</div>"), QRegularExpression::DotMatchesEverythingOption);
    QRegularExpression metaRegex(QStringLiteral("<div\\s+class=\"meta-data\"[^>]*>(.*?)</div>"), QRegularExpression::DotMatchesEverythingOption);
    QRegularExpression tagStripper(QStringLiteral("<[^>]+>"));

    for (int i = 0; i < liPositions.size(); ++i) {
        int startPos = liPositions[i];
        int endPos = (i + 1 < liPositions.size()) ? liPositions[i + 1] : html.indexOf(QStringLiteral("</ul>"), startPos);
        if (endPos == -1) endPos = startPos + 4000;

        QString block = html.mid(startPos, endPos - startPos);

        auto sm = startTimeRegex.match(block);
        auto em = endTimeRegex.match(block);
        if (!sm.hasMatch() || !em.hasMatch()) {
            continue;
        }

        QString startIso = sm.captured(1);
        QString endIso = em.captured(1);

        QString startClock = startIso.section('T', 1, 1).left(5);
        QString endClock = endIso.section('T', 1, 1).left(5);
        if (startClock.length() < 5 || endClock.length() < 5) {
            continue;
        }

        QString datePrefix = startIso.left(10);
        QDate itemDate = QDate::fromString(datePrefix, QStringLiteral("yyyy-MM-dd"));
        if (!itemDate.isValid()) {
            continue;
        }

        int dayOfWeek = itemDate.dayOfWeek() - 1; // 0 = Mon, ..., 6 = Sun

        QString series;
        auto sMatch = seriesRegex.match(block);
        if (sMatch.hasMatch()) {
            series = sMatch.captured(1);
            series.replace(tagStripper, QString());
            series = decodeHtmlEntities(series).trimmed();
        }
        if (series.isEmpty()) series = QStringLiteral("Sendung");

        QString episode;
        auto epMatch = episodeRegex.match(block);
        if (epMatch.hasMatch()) {
            episode = epMatch.captured(1);
            episode.replace(tagStripper, QString());
            episode = decodeHtmlEntities(episode).trimmed();
        }

        QString meta;
        auto metaMatch = metaRegex.match(block);
        if (metaMatch.hasMatch()) {
            meta = metaMatch.captured(1);
            meta.replace(tagStripper, QString());
            meta = decodeHtmlEntities(meta).trimmed();
        }

        QString title = episode.isEmpty() ? series : QStringLiteral("%1: %2").arg(series, episode);
        title.replace('\\', "\\\\").replace('"', "\\\"");

        QString icon = determineIcon(title, meta);
        QString color = determineColor(title, meta);

        BroadcastItem item;
        item.startIso = startIso;
        item.endIso = endIso;
        item.startClock = startClock;
        item.endClock = endClock;
        item.itemDate = itemDate;
        item.dayOfWeek = dayOfWeek;
        item.title = title;
        if (!meta.isEmpty()) {
            meta.replace('\\', "\\\\").replace('"', "\\\"");
            item.description = meta;
        }
        item.icon = icon;
        item.color = color;

        result.append(item);
    }

    return result;
}

QString TvProgramFetcher::determineIcon(const QString &title, const QString &meta) const
{
    QString combined = (title + " " + meta).toLower();
    if (combined.contains("zib") || combined.contains("nachricht") || combined.contains("magazin") || combined.contains("zeit im bild")) {
        return QStringLiteral("📰");
    }
    if (combined.contains("wetter")) {
        return QStringLiteral("☀️");
    }
    if (combined.contains("sport") || combined.contains("fussball") || combined.contains("ski")) {
        return QStringLiteral("⚽");
    }
    if (combined.contains("krimi") || combined.contains("thriller") || combined.contains("soko") || 
        combined.contains("wapo") || combined.contains("monk") || combined.contains("death in paradise") || 
        combined.contains("tatort")) {
        return QStringLiteral("🕵️");
    }
    if (combined.contains("comedy") || combined.contains("kabarett") || combined.contains("goldberg") || combined.contains("ma 2412")) {
        return QStringLiteral("😂");
    }
    if (combined.contains("quiz") || combined.contains("smart10") || combined.contains("gefragt") || combined.contains("q1")) {
        return QStringLiteral("❓");
    }
    if (combined.contains("zeichentrick") || combined.contains("puppen") || combined.contains("kasperl") || 
        combined.contains("kids") || combined.contains("wickie") || combined.contains("garfield") || combined.contains("tom")) {
        return QStringLiteral("🧒");
    }
    if (combined.contains("drama") || combined.contains("film") || combined.contains("serie") || combined.contains("notruf")) {
        return QStringLiteral("🎬");
    }
    return QStringLiteral("📺");
}

QString TvProgramFetcher::determineColor(const QString &title, const QString &meta) const
{
    QString combined = (title + " " + meta).toLower();
    if (combined.contains("zib") || combined.contains("nachricht") || combined.contains("zeit im bild")) {
        return QStringLiteral("#EF4444"); // News Red
    }
    if (combined.contains("wetter")) {
        return QStringLiteral("#F59E0B"); // Sunny Amber
    }
    if (combined.contains("sport") || combined.contains("fussball") || combined.contains("ski")) {
        return QStringLiteral("#10B981"); // Sport Green
    }
    if (combined.contains("krimi") || combined.contains("thriller") || combined.contains("soko") || 
        combined.contains("wapo") || combined.contains("monk") || combined.contains("death in paradise") || 
        combined.contains("tatort")) {
        return QStringLiteral("#8B5CF6"); // Crime Purple
    }
    if (combined.contains("comedy") || combined.contains("kabarett") || combined.contains("goldberg") || combined.contains("ma 2412")) {
        return QStringLiteral("#EC4899"); // Comedy Pink
    }
    if (combined.contains("quiz") || combined.contains("smart10") || combined.contains("gefragt") || combined.contains("q1")) {
        return QStringLiteral("#06B6D4"); // Quiz Cyan
    }
    if (combined.contains("zeichentrick") || combined.contains("puppen") || combined.contains("kasperl") || 
        combined.contains("kids") || combined.contains("wickie") || combined.contains("garfield") || combined.contains("tom")) {
        return QStringLiteral("#F97316"); // Kids Orange
    }
    if (combined.contains("drama") || combined.contains("film") || combined.contains("serie") || combined.contains("notruf")) {
        return QStringLiteral("#3B82F6"); // Drama Blue
    }
    return QStringLiteral("#64748B"); // Slate
}
