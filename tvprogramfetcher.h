#pragma once

#include <QObject>
#include <QString>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QMap>
#include <QDate>
#include <qqmlintegration.h>

class DayPlanModel;

class TvProgramFetcher : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString channel READ channel WRITE setChannel NOTIFY channelChanged)
    Q_PROPERTY(int daysToFetch READ daysToFetch WRITE setDaysToFetch NOTIFY daysToFetchChanged)
    Q_PROPERTY(DayPlanModel* targetModel READ targetModel WRITE setTargetModel NOTIFY targetModelChanged)
    Q_PROPERTY(int lastItemCount READ lastItemCount NOTIFY lastItemCountChanged)
    Q_PROPERTY(QString lastFetchedYaml READ lastFetchedYaml NOTIFY lastFetchedYamlChanged)

public:
    explicit TvProgramFetcher(QObject *parent = nullptr);
    ~TvProgramFetcher() override;

    bool isLoading() const { return m_isLoading; }
    QString statusMessage() const { return m_statusMessage; }
    QString channel() const { return m_channel; }
    void setChannel(const QString &channel);

    int daysToFetch() const { return m_daysToFetch; }
    void setDaysToFetch(int days);

    DayPlanModel* targetModel() const { return m_targetModel; }
    void setTargetModel(DayPlanModel *model);

    int lastItemCount() const { return m_lastItemCount; }
    QString lastFetchedYaml() const { return m_lastFetchedYaml; }

    Q_INVOKABLE void fetchProgram(const QString &channel = QString(), int days = -1);
    Q_INVOKABLE void cancel();

signals:
    void isLoadingChanged();
    void statusMessageChanged();
    void channelChanged();
    void daysToFetchChanged();
    void targetModelChanged();
    void lastItemCountChanged();
    void lastFetchedYamlChanged();
    void fetchStarted();
    void fetchFinished(bool success, const QString &message);
    void yamlReady(const QString &yaml);

private slots:
    void onInitialPageReplyFinished();
    void onSubDayReplyFinished();

private:
    struct BroadcastItem {
        QString startIso;
        QString endIso;
        QString startClock;
        QString endClock;
        QDate itemDate;
        int dayOfWeek = 0; // 0 = Mon .. 6 = Sun
        QString title;
        QString description;
        QString icon;
        QString color;
    };

    void abortAllRequests();
    void finalizeParsing();
    QList<BroadcastItem> extractBroadcastsFromHtml(const QString &html) const;
    QString determineIcon(const QString &title, const QString &meta) const;
    QString determineColor(const QString &title, const QString &meta) const;

    QNetworkAccessManager *m_nam = nullptr;
    QNetworkReply *m_initialReply = nullptr;
    QMap<QNetworkReply*, int> m_pendingReplies;
    QMap<int, QString> m_dayHtmls;
    DayPlanModel *m_targetModel = nullptr;

    bool m_isLoading = false;
    QString m_statusMessage;
    QString m_channel = QStringLiteral("orf1");
    int m_daysToFetch = 7;
    int m_totalDaysToFetch = 0;
    int m_lastItemCount = 0;
    QString m_lastFetchedYaml;
};
