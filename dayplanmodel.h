#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <qqmlintegration.h>

class DayPlanModel : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList items READ items NOTIFY modelChanged)
    Q_PROPERTY(QVariantList flatItems READ flatItems NOTIFY modelChanged)
    Q_PROPERTY(QVariantList intervals READ intervals NOTIFY modelChanged)
    Q_PROPERTY(QVariantList pointItems READ pointItems NOTIFY modelChanged)
    Q_PROPERTY(QVariantList levels READ levels NOTIFY modelChanged)
    Q_PROPERTY(QVariantList levelMaxDurations READ levelMaxDurations NOTIFY modelChanged)
    Q_PROPERTY(QString rawYaml READ rawYaml WRITE setRawYaml NOTIFY rawYamlChanged)
    Q_PROPERTY(QString title READ title NOTIFY modelChanged)
    Q_PROPERTY(int totalItemCount READ totalItemCount NOTIFY modelChanged)
    Q_PROPERTY(int maxLevel READ maxLevel NOTIFY modelChanged)

public:
    explicit DayPlanModel(QObject *parent = nullptr);

    QVariantList items() const { return m_items; }
    QVariantList flatItems() const { return m_flatItems; }
    QVariantList intervals() const { return m_intervals; }
    QVariantList pointItems() const { return m_pointItems; }
    QVariantList levels() const { return m_levels; }
    QVariantList levelMaxDurations() const { return m_levelMaxDurations; }
    QString rawYaml() const { return m_rawYaml; }
    void setRawYaml(const QString &yaml);
    QString title() const { return m_title; }
    int totalItemCount() const { return m_flatItems.size(); }
    int maxLevel() const { return m_maxLevel; }

    Q_INVOKABLE bool loadYaml(const QString &yamlText);
    Q_INVOKABLE bool loadFile(const QString &filePath);
    Q_INVOKABLE void loadDefaultPlan();

signals:
    void modelChanged();
    void rawYamlChanged();

private:
    void processRawItems(const QVariantList &rawList);
    void resolveItem(const QVariantMap &rawItem, double parentStart, double parentDuration, int level, const QString &parentTitle, const QString &parentColor = QString(), int parentDay = -1);

    QString m_rawYaml;
    QString m_title;
    int m_maxLevel = 0;
    QVariantList m_items;
    QVariantList m_flatItems;
    QVariantList m_intervals;
    QVariantList m_pointItems;
    QVariantList m_levels;
    QVariantList m_levelMaxDurations;
};
