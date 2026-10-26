#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QSettings>
#include <qqmlintegration.h>
#include "mealplanmanager.h"
#include "fooddatabase.h"

class GameLevelManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int currentLevel READ currentLevel WRITE setCurrentLevel NOTIFY currentLevelChanged)
    Q_PROPERTY(QVariantMap currentLevelData READ currentLevelData NOTIFY currentLevelChanged)
    Q_PROPERTY(QVariantList allLevels READ allLevels NOTIFY levelsChanged)
    Q_PROPERTY(QVariantList heroModifiers READ heroModifiers NOTIFY heroModifiersChanged)
    Q_PROPERTY(QStringList activeHeroModifiers READ activeHeroModifiers NOTIFY activeHeroModifiersChanged)

public:
    explicit GameLevelManager(QObject *parent = nullptr);

    int currentLevel() const { return m_currentLevel; }
    void setCurrentLevel(int level);

    QVariantMap currentLevelData() const;
    QVariantList allLevels() const { return m_allLevels; }
    QVariantList heroModifiers() const { return m_heroModifiers; }
    QStringList activeHeroModifiers() const { return m_activeHeroModifiers; }

    Q_INVOKABLE QVariantMap getLevel(int levelId) const;
    Q_INVOKABLE int getStars(int levelId) const;
    Q_INVOKABLE void saveStars(int levelId, int stars);
    Q_INVOKABLE QVariantMap evaluatePlan(MealPlanManager *planManager);
    Q_INVOKABLE QVariantMap checkAllLevelConstraints(MealPlanManager *planManager);

    Q_INVOKABLE void toggleHeroModifier(const QString &heroId);
    Q_INVOKABLE bool isHeroModifierActive(const QString &heroId) const;
    Q_INVOKABLE void clearHeroModifiers();
    Q_INVOKABLE void loadGoldenPlan(MealPlanManager *planManager, QObject *foodDbObj = nullptr);
    Q_INVOKABLE void cheatSolveAll(MealPlanManager *planManager, QObject *foodDbObj = nullptr);
    Q_INVOKABLE void resetAllProgress();

signals:
    void currentLevelChanged();
    void levelsChanged();
    void heroModifiersChanged();
    void activeHeroModifiersChanged();
    void evaluationCompleted(const QVariantMap &result);

private:
    void initializeLevels();
    void initializeHeroModifiers();

    int m_currentLevel = 1;
    QVariantList m_allLevels;
    QVariantList m_heroModifiers;
    QStringList m_activeHeroModifiers;
    QSettings m_settings;
};
