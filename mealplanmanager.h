#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlintegration.h>

class DayPlanModel;

class MealPlanManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList meals READ meals NOTIFY planChanged)
    Q_PROPERTY(double totalCalories READ totalCalories NOTIFY planChanged)
    Q_PROPERTY(double totalCarbs READ totalCarbs NOTIFY planChanged)
    Q_PROPERTY(double totalProtein READ totalProtein NOTIFY planChanged)
    Q_PROPERTY(double totalFat READ totalFat NOTIFY planChanged)
    Q_PROPERTY(double totalFiber READ totalFiber NOTIFY planChanged)
    Q_PROPERTY(double carbPercent READ carbPercent NOTIFY planChanged)
    Q_PROPERTY(double proteinPercent READ proteinPercent NOTIFY planChanged)
    Q_PROPERTY(double fatPercent READ fatPercent NOTIFY planChanged)
    Q_PROPERTY(int mealCount READ mealCount NOTIFY planChanged)
    Q_PROPERTY(int totalItemCount READ totalItemCount NOTIFY planChanged)

    // User Profile & Energy Needs
    Q_PROPERTY(QString userName READ userName WRITE setUserName NOTIFY userProfileChanged)
    Q_PROPERTY(double baseCalories READ baseCalories WRITE setBaseCalories NOTIFY userProfileChanged)
    Q_PROPERTY(int userAge READ userAge WRITE setUserAge NOTIFY userProfileChanged)
    Q_PROPERTY(double userWeight READ userWeight WRITE setUserWeight NOTIFY userProfileChanged)
    Q_PROPERTY(double userHeight READ userHeight WRITE setUserHeight NOTIFY userProfileChanged)
    Q_PROPERTY(QString userSex READ userSex WRITE setUserSex NOTIFY userProfileChanged)
    Q_PROPERTY(QString userSport READ userSport WRITE setUserSport NOTIFY userProfileChanged)
    Q_PROPERTY(QString sportDisplayName READ sportDisplayName NOTIFY userProfileChanged)
    Q_PROPERTY(QString sportDescription READ sportDescription NOTIFY userProfileChanged)
    Q_PROPERTY(double targetCarbPercent READ targetCarbPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double targetProteinPercent READ targetProteinPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double targetFatPercent READ targetFatPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double minCarbPercent READ minCarbPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double maxCarbPercent READ maxCarbPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double minProteinPercent READ minProteinPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double maxProteinPercent READ maxProteinPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double minFatPercent READ minFatPercent NOTIFY userProfileChanged)
    Q_PROPERTY(double maxFatPercent READ maxFatPercent NOTIFY userProfileChanged)
    Q_PROPERTY(QVariantList availableSports READ availableSports CONSTANT)
    Q_PROPERTY(double estimatedBmr READ estimatedBmr NOTIFY userProfileChanged)

    // Workout & Target Totals
    Q_PROPERTY(double targetCalories READ targetCalories NOTIFY planChanged)
    Q_PROPERTY(double totalWorkoutCalories READ totalWorkoutCalories NOTIFY planChanged)
    Q_PROPERTY(double totalWorkoutCarbs READ totalWorkoutCarbs NOTIFY planChanged)
    Q_PROPERTY(double totalWorkoutProtein READ totalWorkoutProtein NOTIFY planChanged)
    Q_PROPERTY(double totalWorkoutFat READ totalWorkoutFat NOTIFY planChanged)
    Q_PROPERTY(int workoutCount READ workoutCount NOTIFY planChanged)

    // Extended micronutrients & lipids
    Q_PROPERTY(double totalSatFat READ totalSatFat NOTIFY planChanged)
    Q_PROPERTY(double totalMufa READ totalMufa NOTIFY planChanged)
    Q_PROPERTY(double totalPufa READ totalPufa NOTIFY planChanged)
    Q_PROPERTY(double totalOmega3 READ totalOmega3 NOTIFY planChanged)
    Q_PROPERTY(double totalOmega6 READ totalOmega6 NOTIFY planChanged)
    Q_PROPERTY(double totalCalcium READ totalCalcium NOTIFY planChanged)
    Q_PROPERTY(double totalIron READ totalIron NOTIFY planChanged)
    Q_PROPERTY(double totalZinc READ totalZinc NOTIFY planChanged)
    Q_PROPERTY(double totalCopper READ totalCopper NOTIFY planChanged)
    Q_PROPERTY(double totalMagnesium READ totalMagnesium NOTIFY planChanged)
    Q_PROPERTY(double totalPotassium READ totalPotassium NOTIFY planChanged)
    Q_PROPERTY(double totalSodium READ totalSodium NOTIFY planChanged)
    Q_PROPERTY(double totalVitaminA READ totalVitaminA NOTIFY planChanged)
    Q_PROPERTY(double totalVitaminC READ totalVitaminC NOTIFY planChanged)
    Q_PROPERTY(double totalVitaminD READ totalVitaminD NOTIFY planChanged)
    Q_PROPERTY(double totalVitaminE READ totalVitaminE NOTIFY planChanged)
    Q_PROPERTY(double totalVitaminK READ totalVitaminK NOTIFY planChanged)
    Q_PROPERTY(double totalThiamine READ totalThiamine NOTIFY planChanged)
    Q_PROPERTY(double totalLeucine READ totalLeucine NOTIFY planChanged)
    Q_PROPERTY(double totalTryptophan READ totalTryptophan NOTIFY planChanged)
    Q_PROPERTY(double totalPhytateMg READ totalPhytateMg NOTIFY planChanged)
    Q_PROPERTY(double totalOxalateMg READ totalOxalateMg NOTIFY planChanged)

public:
    explicit MealPlanManager(QObject *parent = nullptr);

    QVariantList meals() const { return m_meals; }
    double totalCalories() const { return m_totalCalories; }
    double totalCarbs() const { return m_totalCarbs; }
    double totalProtein() const { return m_totalProtein; }
    double totalFat() const { return m_totalFat; }
    double totalFiber() const { return m_totalFiber; }
    double carbPercent() const { return m_carbPercent; }
    double proteinPercent() const { return m_proteinPercent; }
    double fatPercent() const { return m_fatPercent; }
    int mealCount() const { return m_meals.size(); }
    int totalItemCount() const { return m_totalItemCount; }

    double totalSatFat() const { return m_totalSatFat; }
    double totalMufa() const { return m_totalMufa; }
    double totalPufa() const { return m_totalPufa; }
    double totalOmega3() const { return m_totalOmega3; }
    double totalOmega6() const { return m_totalOmega6; }
    double totalCalcium() const { return m_totalCalcium; }
    double totalIron() const { return m_totalIron; }
    double totalZinc() const { return m_totalZinc; }
    double totalCopper() const { return m_totalCopper; }
    double totalMagnesium() const { return m_totalMagnesium; }
    double totalPotassium() const { return m_totalPotassium; }
    double totalSodium() const { return m_totalSodium; }
    double totalVitaminA() const { return m_totalVitaminA; }
    double totalVitaminC() const { return m_totalVitaminC; }
    double totalVitaminD() const { return m_totalVitaminD; }
    double totalVitaminE() const { return m_totalVitaminE; }
    double totalVitaminK() const { return m_totalVitaminK; }
    double totalThiamine() const { return m_totalThiamine; }
    double totalLeucine() const { return m_totalLeucine; }
    double totalTryptophan() const { return m_totalTryptophan; }
    double totalPhytateMg() const { return m_totalPhytateMg; }
    double totalOxalateMg() const { return m_totalOxalateMg; }

    // User Profile Getters & Setters
    QString userName() const { return m_userName; }
    void setUserName(const QString &name);

    double baseCalories() const { return m_baseCalories; }
    void setBaseCalories(double cals);

    int userAge() const { return m_userAge; }
    void setUserAge(int age);

    double userWeight() const { return m_userWeight; }
    void setUserWeight(double weight);

    double userHeight() const { return m_userHeight; }
    void setUserHeight(double height);

    QString userSex() const { return m_userSex; }
    void setUserSex(const QString &sex);

    QString userSport() const { return m_userSport; }
    void setUserSport(const QString &sport);

    QString sportDisplayName() const;
    QString sportDescription() const;
    double targetCarbPercent() const;
    double targetProteinPercent() const;
    double targetFatPercent() const;
    double minCarbPercent() const;
    double maxCarbPercent() const;
    double minProteinPercent() const;
    double maxProteinPercent() const;
    double minFatPercent() const;
    double maxFatPercent() const;
    static QVariantList availableSports();

    double estimatedBmr() const;

    // Workout & Target Getters
    double targetCalories() const { return m_targetCalories; }
    double totalWorkoutCalories() const { return m_totalWorkoutCalories; }
    double totalWorkoutCarbs() const { return m_totalWorkoutCarbs; }
    double totalWorkoutProtein() const { return m_totalWorkoutProtein; }
    double totalWorkoutFat() const { return m_totalWorkoutFat; }
    int workoutCount() const { return m_workoutCount; }

    Q_INVOKABLE void setUserProfile(const QString &name, double baseCalories, double weightKg = 75.0, double heightCm = 178.0, int ageYears = 30, const QString &sex = QStringLiteral("male"), const QString &sport = QStringLiteral("endurance_power"));
    Q_INVOKABLE double calculateEstimatedBmr(double weightKg, double heightCm, int ageYears, const QString &sex) const;

    // Workout management
    Q_INVOKABLE int addWorkout(const QString &type, const QString &time = QStringLiteral("17:00"), int durationMinutes = 60, double customCalories = -1.0, double customCarbs = -1.0, double customProtein = -1.0, double customFat = -1.0);
    Q_INVOKABLE bool updateWorkout(int mealIndex, const QString &type, const QString &time, int durationMinutes, double customCalories = -1.0, double customCarbs = -1.0, double customProtein = -1.0, double customFat = -1.0);
    Q_INVOKABLE static QVariantMap calculateWorkoutMetrics(const QString &type, int durationMinutes, double customCalories = -1.0, double customCarbs = -1.0, double customProtein = -1.0, double customFat = -1.0);

    Q_INVOKABLE int addMeal(const QString &title, const QString &time = QStringLiteral("12:00"), const QString &icon = QStringLiteral("🍽️"), const QString &color = QStringLiteral("#3B82F6"));
    Q_INVOKABLE bool removeMeal(int mealIndex);
    Q_INVOKABLE bool updateMealTime(int mealIndex, const QString &newTime);
    Q_INVOKABLE bool updateMealTitle(int mealIndex, const QString &newTitle);
    Q_INVOKABLE QString mealName(int mealIndex) const;
    Q_INVOKABLE bool addItemToMeal(int mealIndex, const QVariantMap &food, double amount);
    Q_INVOKABLE bool addIngredient(int mealIndex, const QString &foodName, double amount, const QString &category = QString());
    Q_INVOKABLE bool updateItemAmount(int mealIndex, int itemIndex, double newAmount);
    Q_INVOKABLE bool removeItemFromMeal(int mealIndex, int itemIndex);
    Q_INVOKABLE void clearPlan();
    Q_INVOKABLE void loadEmptyPlan();
    Q_INVOKABLE void loadSamplePlan();
    Q_INVOKABLE void loadGoldenPlan(QObject *foodDbObj = nullptr);
    Q_INVOKABLE void setMeals(const QVariantList &meals);
    Q_INVOKABLE QString toJsonString() const;
    Q_INVOKABLE bool loadFromJsonString(const QString &jsonStr);

    Q_INVOKABLE QString toYamlString() const;
    Q_INVOKABLE void syncToDayPlanModel(QObject *dayPlanModelObj);
    Q_INVOKABLE void updateLanguage(const QString &langCode, QObject *foodDbObj = nullptr);

signals:
    void planChanged();
    void userProfileChanged();

private:
    void recalculateTotals();
    void sortMealsByTime();
    QVariantMap calculateItemNutrition(const QVariantMap &food, double amount);

    // Profile state
    QString m_userName = QStringLiteral("Athlete");
    double m_baseCalories = 2000.0;
    int m_userAge = 30;
    double m_userWeight = 75.0;
    double m_userHeight = 178.0;
    QString m_userSex = QStringLiteral("male");
    QString m_userSport = QStringLiteral("endurance_power");

    // Dynamic targets & workouts
    double m_targetCalories = 2000.0;
    double m_totalWorkoutCalories = 0.0;
    double m_totalWorkoutCarbs = 0.0;
    double m_totalWorkoutProtein = 0.0;
    double m_totalWorkoutFat = 0.0;
    int m_workoutCount = 0;

    QVariantList m_meals;
    double m_totalCalories = 0.0;
    double m_totalCarbs = 0.0;
    double m_totalProtein = 0.0;
    double m_totalFat = 0.0;
    double m_totalFiber = 0.0;
    double m_carbPercent = 0.0;
    double m_proteinPercent = 0.0;
    double m_fatPercent = 0.0;
    int m_totalItemCount = 0;

    double m_totalSatFat = 0.0;
    double m_totalMufa = 0.0;
    double m_totalPufa = 0.0;
    double m_totalOmega3 = 0.0;
    double m_totalOmega6 = 0.0;
    double m_totalCalcium = 0.0;
    double m_totalIron = 0.0;
    double m_totalZinc = 0.0;
    double m_totalCopper = 0.0;
    double m_totalMagnesium = 0.0;
    double m_totalPotassium = 0.0;
    double m_totalSodium = 0.0;
    double m_totalVitaminA = 0.0;
    double m_totalVitaminC = 0.0;
    double m_totalVitaminD = 0.0;
    double m_totalVitaminE = 0.0;
    double m_totalVitaminK = 0.0;
    double m_totalThiamine = 0.0;
    double m_totalLeucine = 0.0;
    double m_totalTryptophan = 0.0;
    double m_totalPhytateMg = 0.0;
    double m_totalOxalateMg = 0.0;
};
