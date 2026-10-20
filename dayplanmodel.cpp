#include "dayplanmodel.h"
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QCoreApplication>
#include <cmath>

namespace {

double parseTimeToHours(const QString &rawStr, double parentStart = 0.0)
{
    QString str = rawStr.trimmed();
    if (str.startsWith('\"') && str.endsWith('\"') && str.length() >= 2)
        str = str.mid(1, str.length() - 2).trimmed();
    if (str.startsWith('\'') && str.endsWith('\'') && str.length() >= 2)
        str = str.mid(1, str.length() - 2).trimmed();

    bool isRelative = str.startsWith('+');
    if (isRelative)
        str = str.mid(1).trimmed();

    QStringList parts = str.split(':');
    if (parts.isEmpty())
        return 0.0;

    double hours = parts[0].toDouble();
    double minutes = (parts.size() > 1) ? parts[1].toDouble() : 0.0;
    double total = hours + minutes / 60.0;

    if (isRelative) {
        double res = parentStart + total;
        while (res >= 24.0) res -= 24.0;
        while (res < 0.0) res += 24.0;
        return res;
    }

    while (total >= 24.0) total -= 24.0;
    while (total < 0.0) total += 24.0;
    return total;
}

double parseDurationToHours(const QString &rawStr)
{
    QString str = rawStr.trimmed();
    if (str.startsWith('\"') && str.endsWith('\"') && str.length() >= 2)
        str = str.mid(1, str.length() - 2).trimmed();
    if (str.startsWith('+'))
        str = str.mid(1).trimmed();

    QStringList parts = str.split(':');
    if (parts.isEmpty())
        return 0.0;

    double hours = parts[0].toDouble();
    double minutes = (parts.size() > 1) ? parts[1].toDouble() : 0.0;
    return hours + minutes / 60.0;
}

QString formatHoursToClock(double hours)
{
    while (hours >= 24.0) hours -= 24.0;
    while (hours < 0.0) hours += 24.0;
    int h = static_cast<int>(hours);
    int m = static_cast<int>(std::round((hours - h) * 60.0));
    if (m >= 60) {
        h = (h + 1) % 24;
        m = 0;
    }
    return QString("%1:%2")
        .arg(h, 2, 10, QChar('0'))
        .arg(m, 2, 10, QChar('0'));
}

QString cleanScalar(const QString &val)
{
    QString s = val.trimmed();
    if ((s.startsWith('\"') && s.endsWith('\"')) || (s.startsWith('\'') && s.endsWith('\''))) {
        if (s.length() >= 2)
            s = s.mid(1, s.length() - 2);
    }
    return s.trimmed();
}

// Lightweight recursive YAML parser for the day plan format
struct YamlLine {
    int indent;
    QString text;
    int lineNum;
};

QVariant parseYamlBlock(const QList<YamlLine> &lines, int &index, int currentIndent)
{
    if (index >= lines.size())
        return QVariant();

    // Check if the current block is a list or a map
    bool isList = false;
    for (int i = index; i < lines.size(); ++i) {
        if (lines[i].indent < currentIndent)
            break;
        if (lines[i].indent == currentIndent) {
            if (lines[i].text.startsWith("- "))
                isList = true;
            break;
        }
    }

    if (isList) {
        QVariantList list;
        while (index < lines.size()) {
            if (lines[index].indent < currentIndent)
                break;
            if (lines[index].indent > currentIndent) {
                index++;
                continue;
            }

            QString lineText = lines[index].text;
            if (lineText.startsWith("- ")) {
                QString itemContent = lineText.mid(2).trimmed();
                index++;

                QVariantMap itemMap;
                if (!itemContent.isEmpty()) {
                    int colonIdx = itemContent.indexOf(':');
                    if (colonIdx != -1) {
                        QString key = itemContent.left(colonIdx).trimmed();
                        QString val = cleanScalar(itemContent.mid(colonIdx + 1));
                        itemMap[key] = val;
                    }
                }

                // Child properties of this list item
                int childIndent = -1;
                while (index < lines.size()) {
                    if (lines[index].indent <= currentIndent)
                        break;
                    if (childIndent == -1)
                        childIndent = lines[index].indent;
                    if (lines[index].indent < childIndent)
                        break;

                    QString propLine = lines[index].text;
                    int colon = propLine.indexOf(':');
                    if (colon != -1) {
                        QString key = propLine.left(colon).trimmed();
                        QString valStr = propLine.mid(colon + 1).trimmed();

                        if (valStr.isEmpty()) {
                            // Sub-block (e.g. items:)
                            index++;
                            if (index < lines.size() && lines[index].indent > childIndent) {
                                QVariant subBlock = parseYamlBlock(lines, index, lines[index].indent);
                                itemMap[key] = subBlock;
                            }
                        } else {
                            itemMap[key] = cleanScalar(valStr);
                            index++;
                        }
                    } else {
                        index++;
                    }
                }
                list.append(itemMap);
            } else {
                index++;
            }
        }
        return list;
    } else {
        // Map block
        QVariantMap map;
        while (index < lines.size()) {
            if (lines[index].indent < currentIndent)
                break;
            if (lines[index].indent > currentIndent) {
                index++;
                continue;
            }

            QString lineText = lines[index].text;
            int colon = lineText.indexOf(':');
            if (colon != -1) {
                QString key = lineText.left(colon).trimmed();
                QString valStr = lineText.mid(colon + 1).trimmed();

                if (valStr.isEmpty()) {
                    index++;
                    if (index < lines.size() && lines[index].indent > currentIndent) {
                        QVariant subBlock = parseYamlBlock(lines, index, lines[index].indent);
                        map[key] = subBlock;
                    }
                } else {
                    map[key] = cleanScalar(valStr);
                    index++;
                }
            } else {
                index++;
            }
        }
        return map;
    }
}

} // anonymous namespace

DayPlanModel::DayPlanModel(QObject *parent)
    : QObject(parent)
{
    loadDefaultPlan();
}

void DayPlanModel::setRawYaml(const QString &yaml)
{
    if (m_rawYaml != yaml) {
        m_rawYaml = yaml;
        emit rawYamlChanged();
        loadYaml(yaml);
    }
}

bool DayPlanModel::loadYaml(const QString &yamlText)
{
    QStringList rawLines = yamlText.split('\n');
    QList<YamlLine> lines;

    for (int i = 0; i < rawLines.size(); ++i) {
        QString line = rawLines[i];
        // Strip comments
        int hashIdx = line.indexOf('#');
        if (hashIdx != -1)
            line = line.left(hashIdx);

        // Strip trailing CR
        if (line.endsWith('\r'))
            line.chop(1);

        if (line.trimmed().isEmpty())
            continue;

        int indent = 0;
        while (indent < line.length() && line[indent] == ' ')
            indent++;

        YamlLine yl;
        yl.indent = indent;
        yl.text = line.trimmed();
        yl.lineNum = i + 1;
        lines.append(yl);
    }

    if (lines.isEmpty())
        return false;

    int idx = 0;
    QVariant parsed = parseYamlBlock(lines, idx, lines[0].indent);
    QVariantList planList;

    if (parsed.typeId() == QMetaType::QVariantMap) {
        QVariantMap rootMap = parsed.toMap();
        m_title = rootMap.value("title", "Daily Plan").toString();
        planList = rootMap.value("plan").toList();
    } else if (parsed.typeId() == QMetaType::QVariantList) {
        m_title = "Daily Plan";
        planList = parsed.toList();
    }

    processRawItems(planList);
    m_rawYaml = yamlText;
    emit rawYamlChanged();
    emit modelChanged();
    return true;
}

bool DayPlanModel::loadFile(const QString &filePath)
{
    QString path = filePath;
    QFile file(path);
    if (!file.exists()) {
        path = QCoreApplication::applicationDirPath() + "/" + filePath;
        file.setFileName(path);
    }
    if (!file.exists()) {
        path = QCoreApplication::applicationDirPath() + "/../../" + filePath;
        file.setFileName(path);
    }
    if (!file.exists()) {
        path = "c:/Users/MiCHi/Documents/QtSpeis/" + filePath;
        file.setFileName(path);
    }
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    QTextStream in(&file);
    QString text = in.readAll();
    file.close();
    m_rawYaml = text;
    emit rawYamlChanged();
    return loadYaml(text);
}

void DayPlanModel::processRawItems(const QVariantList &rawList)
{
    m_items.clear();
    m_flatItems.clear();
    m_intervals.clear();
    m_pointItems.clear();
    m_levels.clear();
    m_levelMaxDurations.clear();
    m_maxLevel = 0;

    for (const QVariant &itemVar : rawList) {
        QVariantMap rawItem = itemVar.toMap();
        resolveItem(rawItem, 0.0, 24.0, 0, QString(), QString());
    }
}

void DayPlanModel::resolveItem(const QVariantMap &rawItem, double parentStart, double parentDuration, int level, const QString &parentTitle, const QString &parentColor, int parentDay)
{
    if (level > m_maxLevel)
        m_maxLevel = level;

    int itemDay = parentDay;
    bool repeatDaily = false;
    if (rawItem.contains("day")) {
        QVariant dayVal = rawItem.value("day");
        bool ok = false;
        int num = dayVal.toInt(&ok);
        if (ok && num >= 0 && num < 7) {
            itemDay = num;
        } else {
            QString dStr = dayVal.toString().trimmed().toLower();
            if (dStr == "all" || dStr == "every" || dStr == "daily") {
                repeatDaily = true;
            } else if (dStr.startsWith("mon") || dStr == "0") itemDay = 0;
            else if (dStr.startsWith("tue") || dStr == "1") itemDay = 1;
            else if (dStr.startsWith("wed") || dStr == "2") itemDay = 2;
            else if (dStr.startsWith("thu") || dStr == "3") itemDay = 3;
            else if (dStr.startsWith("fri") || dStr == "4") itemDay = 4;
            else if (dStr.startsWith("sat") || dStr == "5") itemDay = 5;
            else if (dStr.startsWith("sun") || dStr == "6") itemDay = 6;
        }
    }

    QString title = rawItem.value("title", "Untitled").toString();
    QString icon = rawItem.value("icon", "📌").toString();
    QString color = rawItem.value("color").toString();
    if (color.isEmpty())
        color = parentColor;
    QString description = rawItem.value("description").toString();

    bool hasTime = rawItem.contains("time");
    bool hasStart = rawItem.contains("start");
    bool hasEnd = rawItem.contains("end");
    bool hasDuration = rawItem.contains("duration");

    double startTime = 0.0;
    double endTime = 0.0;
    double duration = 0.0;
    bool isInterval = false;
    bool isPoint = false;
    bool isUntimedStep = false;
    bool crossesMidnight = false;

    if (hasStart && (hasEnd || hasDuration)) {
        isInterval = true;
        startTime = parseTimeToHours(rawItem.value("start").toString(), parentStart);

        if (hasDuration) {
            duration = parseDurationToHours(rawItem.value("duration").toString());
            endTime = std::fmod(startTime + duration, 24.0);
            crossesMidnight = (startTime + duration >= 24.0);
        } else {
            endTime = parseTimeToHours(rawItem.value("end").toString(), parentStart);
            if (endTime < startTime) {
                duration = (24.0 - startTime) + endTime;
                crossesMidnight = true;
            } else {
                duration = endTime - startTime;
                crossesMidnight = false;
            }
        }
    } else if (hasTime) {
        isPoint = true;
        startTime = parseTimeToHours(rawItem.value("time").toString(), parentStart);
        endTime = startTime;
        duration = 0.0;
    } else {
        // Ordered untimed child item
        isUntimedStep = true;
        isPoint = true;
        startTime = parentStart;
        endTime = parentStart;
        duration = 0.0;
    }

    if (rawItem.contains("orderIndex")) {
        isUntimedStep = true;
    }

    QVariantList childList = rawItem.value("items").toList();

    QVariantMap resolved;
    resolved["title"] = title;
    resolved["icon"] = icon;
    resolved["color"] = color;
    resolved["description"] = description;
    resolved["startTime"] = startTime;
    resolved["endTime"] = endTime;
    resolved["duration"] = duration;
    resolved["startClock"] = formatHoursToClock(startTime);
    resolved["endClock"] = formatHoursToClock(endTime);
    resolved["isInterval"] = isInterval;
    resolved["isPoint"] = isPoint;
    resolved["isUntimedStep"] = isUntimedStep;
    resolved["crossesMidnight"] = crossesMidnight;
    resolved["level"] = level;
    resolved["parentTitle"] = parentTitle;
    resolved["hasChildren"] = !childList.isEmpty();
    resolved["childrenCount"] = childList.size();

    if (rawItem.contains("orderIndex")) {
        resolved["orderIndex"] = rawItem.value("orderIndex").toInt();
        resolved["totalSteps"] = rawItem.value("totalSteps").toInt();
    }

    resolved["repeatDaily"] = repeatDaily;
    if (itemDay >= 0 && itemDay < 7) {
        resolved["day"] = itemDay;
        static const char* const dayNames[] = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
        resolved["dayName"] = QString::fromLatin1(dayNames[itemDay]);
    }

    // Append parent item BEFORE children so they appear hierarchically in pre-order
    m_flatItems.append(resolved);
    if (level == 0)
        m_items.append(resolved);

    if (isInterval) {
        m_intervals.append(resolved);

        while (m_levels.size() <= level) {
            m_levels.append(QVariant(QVariantList()));
            m_levelMaxDurations.append(0.0);
        }
        QVariantList lvlList = m_levels[level].toList();
        lvlList.append(resolved);
        m_levels[level] = lvlList;

        double currentMax = m_levelMaxDurations[level].toDouble();
        if (duration > currentMax) {
            m_levelMaxDurations[level] = duration;
        }
    } else {
        m_pointItems.append(resolved);
    }

    // Process nested items
    if (!childList.isEmpty() && isInterval) {
        // Check for untimed children to assign sequential step orders
        int untimedCount = 0;
        for (const QVariant &cVar : childList) {
            QVariantMap cMap = cVar.toMap();
            if (!cMap.contains("time") && !cMap.contains("start"))
                untimedCount++;
        }

        int untimedIndex = 0;
        for (const QVariant &cVar : childList) {
            QVariantMap cMap = cVar.toMap();
            bool childIsUntimed = (!cMap.contains("time") && !cMap.contains("start"));

            if (childIsUntimed) {
                // Assign partitioned time slice inside parent interval
                double stepOffset = (untimedIndex + 0.5) * (duration / std::max(1, untimedCount));
                double stepTime = std::fmod(startTime + stepOffset, 24.0);
                cMap["time"] = formatHoursToClock(stepTime);
                cMap["orderIndex"] = untimedIndex + 1;
                cMap["totalSteps"] = untimedCount;
                untimedIndex++;
            }

            resolveItem(cMap, startTime, duration, level + 1, title, color, itemDay);
        }
    }
}

void DayPlanModel::loadDefaultPlan()
{
    const QString defaultYaml = R"(version: "1.0"
title: "Benjamin Franklin's Daily Schedule"

plan:
  - title: Sleep & Rest
    start: "22:00"
    end: "05:00"
    icon: 😴
    color: "#1E3A8A"

  - title: Morning Preparation & Reflection
    start: "05:00"
    duration: "03:00"
    icon: 🌅
    color: "#3B82F6"
    items:
      - title: Wash & Personal Care
        icon: 🚿
      - title: Address Powerful Goodness (Prayer)
        icon: 🙏
      - title: Contrive Day's Business & Resolution
        icon: 📝
      - title: Morning Study
        icon: 📖
      - title: Breakfast
        icon: 🍳

  - title: Morning Work Block
    start: "08:00"
    duration: "04:00"
    icon: 💼
    color: "#8B5CF6"

  - title: Midday Break & Reading
    start: "12:00"
    duration: "02:00"
    icon: 🍽️
    color: "#10B981"
    items:
      - title: Read & Overlook Accounts
        icon: 📊
      - title: Lunch / Dine
        icon: 🥗

  - title: Afternoon Work Block
    start: "14:00"
    duration: "04:00"
    icon: ⚙️
    color: "#8B5CF6"

  - title: Evening Order, Music & Diversion
    start: "18:00"
    end: "22:00"
    icon: 🎻
    color: "#F59E0B"
    items:
      - title: Put Things in Their Places
        icon: 🧹
      - title: Supper
        icon: 🍲
      - title: Music & Conversation
        icon: 🎶
      - title: Examination of the Day
        icon: 🔍
)";

    loadYaml(defaultYaml);
}
