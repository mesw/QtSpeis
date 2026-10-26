#include "mealplanmanager.h"
#include "fooddatabase.h"
#include <QMetaObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <algorithm>
#include <cmath>
#include <QDebug>

static int parseTimeToMinutes(const QString &timeStr)
{
    QString t = timeStr.trimmed();
    if (t.isEmpty()) return 12 * 60;

    QStringList parts = t.split(QLatin1Char(':'));
    if (parts.size() >= 2) {
        bool okH = false, okM = false;
        int h = parts[0].toInt(&okH);
        int m = parts[1].toInt(&okM);
        if (okH && okM) {
            return std::clamp(h, 0, 23) * 60 + std::clamp(m, 0, 59);
        }
    }
    bool ok = false;
    int h = t.toInt(&ok);
    if (ok) {
        return std::clamp(h, 0, 23) * 60;
    }
    return 12 * 60;
}

static QString normalizeTimeString(const QString &timeStr)
{
    int mins = parseTimeToMinutes(timeStr);
    int h = mins / 60;
    int m = mins % 60;
    return QString::asprintf("%02d:%02d", h, m);
}

MealPlanManager::MealPlanManager(QObject *parent)
    : QObject(parent)
{
    m_targetCalories = m_baseCalories;
    loadEmptyPlan();
}

void MealPlanManager::setUserName(const QString &name)
{
    QString n = name.trimmed();
    if (n.isEmpty()) n = QStringLiteral("Athlete");
    if (m_userName != n) {
        m_userName = n;
        emit userProfileChanged();
    }
}

void MealPlanManager::setBaseCalories(double cals)
{
    double c = std::max(500.0, std::min(10000.0, cals));
    if (std::abs(m_baseCalories - c) > 0.1) {
        m_baseCalories = c;
        recalculateTotals();
        emit userProfileChanged();
        emit planChanged();
    }
}

void MealPlanManager::setUserAge(int age)
{
    int a = std::clamp(age, 10, 120);
    if (m_userAge != a) {
        m_userAge = a;
        emit userProfileChanged();
    }
}

void MealPlanManager::setUserWeight(double weight)
{
    double w = std::max(20.0, std::min(300.0, weight));
    if (std::abs(m_userWeight - w) > 0.1) {
        m_userWeight = w;
        emit userProfileChanged();
    }
}

void MealPlanManager::setUserHeight(double height)
{
    double h = std::max(80.0, std::min(250.0, height));
    if (std::abs(m_userHeight - h) > 0.1) {
        m_userHeight = h;
        emit userProfileChanged();
    }
}

void MealPlanManager::setUserSex(const QString &sex)
{
    QString s = sex.trimmed().toLower();
    if (s != QStringLiteral("female")) s = QStringLiteral("male");
    if (m_userSex != s) {
        m_userSex = s;
        emit userProfileChanged();
    }
}

double MealPlanManager::estimatedBmr() const
{
    return calculateEstimatedBmr(m_userWeight, m_userHeight, m_userAge, m_userSex);
}

double MealPlanManager::calculateEstimatedBmr(double weightKg, double heightCm, int ageYears, const QString &sex) const
{
    double w = weightKg > 0.0 ? weightKg : 75.0;
    double h = heightCm > 0.0 ? heightCm : 178.0;
    int a = ageYears > 0 ? ageYears : 30;
    double bmr = 10.0 * w + 6.25 * h - 5.0 * a;
    if (sex.trimmed().toLower() == QStringLiteral("female")) {
        bmr -= 161.0;
    } else {
        bmr += 5.0;
    }
    return std::round(bmr);
}

struct SportInfo {
    const char *id;
    const char *nameDe;
    const char *nameEn;
    const char *descDe;
    const char *descEn;
    double carbPct;
    double minCarb;
    double maxCarb;
    double protPct;
    double minProt;
    double maxProt;
    double fatPct;
    double minFat;
    double maxFat;
};

static const SportInfo s_sports[] = {
    { "endurance_power", "Ausdauersport mit hohem Krafteinsatz", "Endurance with High Power",
      "Radsport, Schwimmen, Triathlon, Rudern, Biathlon, Bergsteigen", "Cycling, Swimming, Triathlon, Rowing, Biathlon, Mountaineering",
      55.0, 50.0, 58.0, 15.0, 12.0, 18.0, 30.0, 27.0, 33.0 },
    { "endurance_pure", "Ausdauersportarten", "Pure Endurance",
      "Mittel- und Langstreckenlauf, Skilanglauf", "Middle/Long Distance Running, Cross-Country Skiing",
      60.0, 56.0, 64.0, 14.0, 12.0, 16.0, 26.0, 24.0, 28.0 },
    { "general_sports", "Nicht klassifizierbare Sportarten", "Technical & Precision Sports",
      "Schießen, Segeln, Motorsport, Reiten, Golf", "Shooting, Sailing, Motorsport, Equestrian, Golf",
      60.0, 56.0, 64.0, 12.0, 10.0, 14.0, 28.0, 26.0, 30.0 },
    { "team_sports", "Spielsportarten", "Team & Ball Sports",
      "Fußball, Handball, Tennis, Eishockey, Basketball", "Football, Handball, Tennis, Ice Hockey, Basketball",
      55.0, 50.0, 58.0, 15.0, 12.0, 18.0, 30.0, 27.0, 33.0 },
    { "combat_sports", "Kampfsportarten", "Combat Sports",
      "Boxen, Judo, Karate, Taekwondo", "Boxing, Judo, Karate, Taekwondo",
      55.0, 50.0, 58.0, 16.0, 12.0, 20.0, 29.0, 25.0, 33.0 },
    { "power_speed", "Schnellkraftsportarten", "Speed & Power",
      "Sprint, Skisport alpin, Sprungdisziplinen, Turnen, Volleyball, Fechten", "Sprint, Alpine Skiing, Jumping, Gymnastics, Volleyball, Fencing",
      55.0, 50.0, 58.0, 16.0, 12.0, 20.0, 29.0, 25.0, 33.0 },
    { "strength_sports", "Kraftsportarten", "Strength & Bodybuilding",
      "Gewichtheben, Wurf-/Stoßdisziplinen, Bodybuilding", "Weightlifting, Throwing disciplines, Bodybuilding",
      50.0, 45.0, 54.0, 20.0, 15.0, 24.0, 30.0, 26.0, 35.0 },
    { "carboloading", "Vorwettkampfphase (Carboloading)", "Pre-Competition Carboloading",
      "Glykogenspeicher vor Ausdauerwettkampf maximieren (70% C, 10% P, 20% F)", "Maximizing glycogen stores before endurance events",
      70.0, 65.0, 75.0, 10.0, 8.0, 14.0, 20.0, 17.0, 23.0 },
    { "diet_fatloss", "Gewichtsreduktion (Diät / Fettabbau)", "Fat Loss & Diet",
      "Erhöhte Thermogenese & Muskelschutz (mind. 20% Eiweiß)", "Elevated thermogenesis & muscle sparing (min 20% protein)",
      45.0, 40.0, 50.0, 25.0, 20.0, 30.0, 30.0, 25.0, 35.0 }
};

static const SportInfo* findSport(const QString &sportId) {
    for (const auto &s : s_sports) {
        if (sportId == QLatin1String(s.id)) return &s;
    }
    return &s_sports[0]; // default endurance_power
}

void MealPlanManager::setUserSport(const QString &sport)
{
    QString s = sport.trimmed();
    if (s != m_userSport) {
        m_userSport = s;
        emit userProfileChanged();
        emit planChanged();
    }
}

QString MealPlanManager::sportDisplayName() const
{
    const SportInfo *s = findSport(m_userSport);
    return QString::fromUtf8(s->nameDe);
}

QString MealPlanManager::sportDescription() const
{
    const SportInfo *s = findSport(m_userSport);
    return QString::fromUtf8(s->descDe);
}

double MealPlanManager::targetCarbPercent() const { return findSport(m_userSport)->carbPct; }
double MealPlanManager::targetProteinPercent() const { return findSport(m_userSport)->protPct; }
double MealPlanManager::targetFatPercent() const { return findSport(m_userSport)->fatPct; }
double MealPlanManager::minCarbPercent() const { return findSport(m_userSport)->minCarb; }
double MealPlanManager::maxCarbPercent() const { return findSport(m_userSport)->maxCarb; }
double MealPlanManager::minProteinPercent() const { return findSport(m_userSport)->minProt; }
double MealPlanManager::maxProteinPercent() const { return findSport(m_userSport)->maxProt; }
double MealPlanManager::minFatPercent() const { return findSport(m_userSport)->minFat; }
double MealPlanManager::maxFatPercent() const { return findSport(m_userSport)->maxFat; }

QVariantList MealPlanManager::availableSports()
{
    QVariantList list;
    for (const auto &s : s_sports) {
        QVariantMap m;
        m[QStringLiteral("id")] = QString::fromLatin1(s.id);
        m[QStringLiteral("name")] = QString::fromUtf8(s.nameDe);
        m[QStringLiteral("nameDe")] = QString::fromUtf8(s.nameDe);
        m[QStringLiteral("nameEn")] = QString::fromLatin1(s.nameEn);
        m[QStringLiteral("description")] = QString::fromUtf8(s.descDe);
        m[QStringLiteral("descDe")] = QString::fromUtf8(s.descDe);
        m[QStringLiteral("descEn")] = QString::fromLatin1(s.descEn);
        m[QStringLiteral("carbPercent")] = s.carbPct;
        m[QStringLiteral("minCarb")] = s.minCarb;
        m[QStringLiteral("maxCarb")] = s.maxCarb;
        m[QStringLiteral("proteinPercent")] = s.protPct;
        m[QStringLiteral("minProtein")] = s.minProt;
        m[QStringLiteral("maxProtein")] = s.maxProt;
        m[QStringLiteral("fatPercent")] = s.fatPct;
        m[QStringLiteral("minFat")] = s.minFat;
        m[QStringLiteral("maxFat")] = s.maxFat;
        list.append(m);
    }
    return list;
}

void MealPlanManager::setUserProfile(const QString &name, double baseCalories, double weightKg, double heightCm, int ageYears, const QString &sex, const QString &sport)
{
    m_userName = name.trimmed().isEmpty() ? QStringLiteral("Athlete") : name.trimmed();
    m_baseCalories = std::max(500.0, std::min(10000.0, baseCalories));
    m_userWeight = std::max(20.0, std::min(300.0, weightKg));
    m_userHeight = std::max(80.0, std::min(250.0, heightCm));
    m_userAge = std::clamp(ageYears, 10, 120);
    QString s = sex.trimmed().toLower();
    m_userSex = (s == QStringLiteral("female")) ? QStringLiteral("female") : QStringLiteral("male");
    if (!sport.trimmed().isEmpty()) {
        m_userSport = sport.trimmed();
    }

    recalculateTotals();
    emit userProfileChanged();
    emit planChanged();
}

QVariantMap MealPlanManager::calculateWorkoutMetrics(const QString &type, int durationMinutes, double customCalories, double customCarbs, double customProtein, double customFat)
{
    QString t = type.trimmed().toLower();
    double durationHours = qMax(1, durationMinutes) / 60.0;

    QString title = QStringLiteral("Workout");
    QString icon = QStringLiteral("🏃");
    QString color = QStringLiteral("#3B82F6");
    double baseHourlyBurn = 500.0;
    double carbRatio = 0.60;
    double protRatio = 0.10;
    double fatRatio = 0.30;

    if (t.contains(QStringLiteral("stretch")) || t.contains(QStringLiteral("yoga")) || t.contains(QStringLiteral("mobility"))) {
        title = QStringLiteral("Stretching & Mobility");
        icon = QStringLiteral("🧘");
        color = QStringLiteral("#06B6D4");
        baseHourlyBurn = 160.0;
        carbRatio = 0.30;
        protRatio = 0.05;
        fatRatio = 0.65;
    } else if (t.contains(QStringLiteral("endurance")) || t.contains(QStringLiteral("run")) || t.contains(QStringLiteral("cycling")) || t.contains(QStringLiteral("bike")) || t.contains(QStringLiteral("swim"))) {
        title = QStringLiteral("Endurance Cardio");
        icon = QStringLiteral("🏃");
        color = QStringLiteral("#3B82F6");
        baseHourlyBurn = 560.0;
        carbRatio = 0.60;
        protRatio = 0.05;
        fatRatio = 0.35;
    } else if (t.contains(QStringLiteral("strength")) || t.contains(QStringLiteral("weight")) || t.contains(QStringLiteral("hypertrophy")) || t.contains(QStringLiteral("gym"))) {
        title = QStringLiteral("Strength Training");
        icon = QStringLiteral("🏋️");
        color = QStringLiteral("#EA580C");
        baseHourlyBurn = 420.0;
        carbRatio = 0.65;
        protRatio = 0.15;
        fatRatio = 0.20;
    } else if (t.contains(QStringLiteral("interval")) || t.contains(QStringLiteral("hiit")) || t.contains(QStringLiteral("sprint"))) {
        title = QStringLiteral("HIIT & Intervals");
        icon = QStringLiteral("⚡");
        color = QStringLiteral("#DC2626");
        baseHourlyBurn = 680.0;
        carbRatio = 0.80;
        protRatio = 0.05;
        fatRatio = 0.15;
    } else {
        title = QStringLiteral("Custom Workout");
        icon = QStringLiteral("🎯");
        color = QStringLiteral("#8B5CF6");
        baseHourlyBurn = 400.0;
        carbRatio = 0.50;
        protRatio = 0.25;
        fatRatio = 0.25;
    }

    double burnedCals = (customCalories > 0.0) ? customCalories : (baseHourlyBurn * durationHours);
    burnedCals = std::round(burnedCals);

    double cGrams = (customCarbs >= 0.0) ? customCarbs : std::round(((burnedCals * carbRatio) / 4.0) * 10.0) / 10.0;
    double pGrams = (customProtein >= 0.0) ? customProtein : std::round(((burnedCals * protRatio) / 4.0) * 10.0) / 10.0;
    double fGrams = (customFat >= 0.0) ? customFat : std::round(((burnedCals * fatRatio) / 9.0) * 10.0) / 10.0;

    QVariantMap res;
    res[QStringLiteral("type")] = t;
    res[QStringLiteral("title")] = title;
    res[QStringLiteral("icon")] = icon;
    res[QStringLiteral("color")] = color;
    res[QStringLiteral("durationMinutes")] = durationMinutes;
    res[QStringLiteral("calories")] = burnedCals;
    res[QStringLiteral("carbs")] = cGrams;
    res[QStringLiteral("protein")] = pGrams;
    res[QStringLiteral("fat")] = fGrams;
    return res;
}

static int s_mealSeq = 100;
static int s_woSeq = 500;

static bool mealIdExists(const QVariantList &meals, const QString &id)
{
    for (const auto &m : meals) {
        if (m.toMap().value(QStringLiteral("id")).toString() == id) {
            return true;
        }
    }
    return false;
}

static QString nextUniqueMealId(const QVariantList &meals, const QString &prefix, int &seq)
{
    QString candidate;
    do {
        candidate = prefix + QString::number(++seq);
    } while (mealIdExists(meals, candidate));
    return candidate;
}

static void ensureUniqueMealIds(QVariantList &meals)
{
    QStringList seenIds;
    for (int i = 0; i < meals.size(); ++i) {
        QVariantMap meal = meals[i].toMap();
        QString id = meal.value(QStringLiteral("id")).toString().trimmed();
        bool isWo = meal.value(QStringLiteral("isWorkout")).toBool();
        if (id.startsWith(QStringLiteral("meal_"))) {
            bool ok = false;
            int n = id.mid(5).toInt(&ok);
            if (ok && n > s_mealSeq) s_mealSeq = n;
        } else if (id.startsWith(QStringLiteral("workout_"))) {
            bool ok = false;
            int n = id.mid(8).toInt(&ok);
            if (ok && n > s_woSeq) s_woSeq = n;
        }
        if (id.isEmpty() || seenIds.contains(id)) {
            id = isWo ? nextUniqueMealId(meals, QStringLiteral("workout_"), s_woSeq)
                      : nextUniqueMealId(meals, QStringLiteral("meal_"), s_mealSeq);
            meal[QStringLiteral("id")] = id;
            meals[i] = meal;
        }
        seenIds.append(id);
    }
}

int MealPlanManager::addWorkout(const QString &type, const QString &time, int durationMinutes, double customCalories, double customCarbs, double customProtein, double customFat)
{
    QString newId = nextUniqueMealId(m_meals, QStringLiteral("workout_"), s_woSeq);

    QVariantMap metrics = calculateWorkoutMetrics(type, durationMinutes, customCalories, customCarbs, customProtein, customFat);

    QVariantMap workoutMeal;
    workoutMeal[QStringLiteral("id")] = newId;
    workoutMeal[QStringLiteral("title")] = metrics.value(QStringLiteral("title"));
    workoutMeal[QStringLiteral("time")] = normalizeTimeString(time);
    workoutMeal[QStringLiteral("icon")] = metrics.value(QStringLiteral("icon"));
    workoutMeal[QStringLiteral("color")] = metrics.value(QStringLiteral("color"));
    workoutMeal[QStringLiteral("isWorkout")] = true;
    workoutMeal[QStringLiteral("workoutType")] = metrics.value(QStringLiteral("type"));
    workoutMeal[QStringLiteral("duration")] = durationMinutes;
    workoutMeal[QStringLiteral("calories")] = metrics.value(QStringLiteral("calories"));
    workoutMeal[QStringLiteral("carbs")] = metrics.value(QStringLiteral("carbs"));
    workoutMeal[QStringLiteral("protein")] = metrics.value(QStringLiteral("protein"));
    workoutMeal[QStringLiteral("fat")] = metrics.value(QStringLiteral("fat"));
    workoutMeal[QStringLiteral("fiber")] = 0.0;
    workoutMeal[QStringLiteral("items")] = QVariantList();

    m_meals.append(workoutMeal);
    sortMealsByTime();
    recalculateTotals();
    emit planChanged();

    for (int i = 0; i < m_meals.size(); ++i) {
        if (m_meals[i].toMap().value(QStringLiteral("id")).toString() == newId) {
            return i;
        }
    }
    return m_meals.size() - 1;
}

bool MealPlanManager::updateWorkout(int mealIndex, const QString &type, const QString &time, int durationMinutes, double customCalories, double customCarbs, double customProtein, double customFat)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    QVariantMap meal = m_meals[mealIndex].toMap();
    if (!meal.value(QStringLiteral("isWorkout")).toBool()) return false;

    QVariantMap metrics = calculateWorkoutMetrics(type, durationMinutes, customCalories, customCarbs, customProtein, customFat);
    meal[QStringLiteral("title")] = metrics.value(QStringLiteral("title"));
    meal[QStringLiteral("time")] = normalizeTimeString(time);
    meal[QStringLiteral("icon")] = metrics.value(QStringLiteral("icon"));
    meal[QStringLiteral("color")] = metrics.value(QStringLiteral("color"));
    meal[QStringLiteral("workoutType")] = metrics.value(QStringLiteral("type"));
    meal[QStringLiteral("duration")] = durationMinutes;
    meal[QStringLiteral("calories")] = metrics.value(QStringLiteral("calories"));
    meal[QStringLiteral("carbs")] = metrics.value(QStringLiteral("carbs"));
    meal[QStringLiteral("protein")] = metrics.value(QStringLiteral("protein"));
    meal[QStringLiteral("fat")] = metrics.value(QStringLiteral("fat"));

    m_meals[mealIndex] = meal;
    sortMealsByTime();
    recalculateTotals();
    emit planChanged();
    return true;
}

void MealPlanManager::sortMealsByTime()
{
    std::stable_sort(m_meals.begin(), m_meals.end(), [](const QVariant &a, const QVariant &b) {
        int minA = parseTimeToMinutes(a.toMap().value(QStringLiteral("time")).toString());
        int minB = parseTimeToMinutes(b.toMap().value(QStringLiteral("time")).toString());
        return minA < minB;
    });
}

int MealPlanManager::addMeal(const QString &title, const QString &time, const QString &icon, const QString &color)
{
    QString newId = nextUniqueMealId(m_meals, QStringLiteral("meal_"), s_mealSeq);

    QVariantMap meal;
    meal[QStringLiteral("id")] = newId;
    meal[QStringLiteral("title")] = title.trimmed().isEmpty() ? QStringLiteral("New Meal") : title.trimmed();
    meal[QStringLiteral("time")] = normalizeTimeString(time);
    meal[QStringLiteral("icon")] = icon.isEmpty() ? QStringLiteral("🍽️") : icon;
    meal[QStringLiteral("color")] = color.isEmpty() ? QStringLiteral("#3B82F6") : color;
    meal[QStringLiteral("items")] = QVariantList();
    meal[QStringLiteral("calories")] = 0.0;
    meal[QStringLiteral("carbs")] = 0.0;
    meal[QStringLiteral("protein")] = 0.0;
    meal[QStringLiteral("fat")] = 0.0;
    meal[QStringLiteral("fiber")] = 0.0;

    m_meals.append(meal);
    sortMealsByTime();
    recalculateTotals();
    emit planChanged();

    for (int i = 0; i < m_meals.size(); ++i) {
        if (m_meals[i].toMap().value(QStringLiteral("id")).toString() == newId) {
            return i;
        }
    }
    return m_meals.size() - 1;
}

bool MealPlanManager::removeMeal(int mealIndex)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    m_meals.removeAt(mealIndex);
    recalculateTotals();
    emit planChanged();
    return true;
}

bool MealPlanManager::updateMealTime(int mealIndex, const QString &newTime)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    QVariantMap meal = m_meals[mealIndex].toMap();
    meal[QStringLiteral("time")] = normalizeTimeString(newTime);
    m_meals[mealIndex] = meal;
    sortMealsByTime();
    emit planChanged();
    return true;
}

bool MealPlanManager::updateMealTitle(int mealIndex, const QString &newTitle)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    QVariantMap meal = m_meals[mealIndex].toMap();
    meal[QStringLiteral("title")] = newTitle.trimmed();
    m_meals[mealIndex] = meal;
    emit planChanged();
    return true;
}

QString MealPlanManager::mealName(int mealIndex) const
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return QString();
    return m_meals[mealIndex].toMap().value(QStringLiteral("title")).toString();
}

bool MealPlanManager::addIngredient(int mealIndex, const QString &foodName, double amount, const QString &category)
{
    if (m_meals.isEmpty()) {
        addMeal(QStringLiteral("Breakfast"), QStringLiteral("08:00"), QStringLiteral("🍳"), QStringLiteral("#F59E0B"));
        mealIndex = 0;
    } else if (mealIndex < 0 || mealIndex >= m_meals.size()) {
        mealIndex = 0;
    }
    QVariantMap food;
    food[QStringLiteral("name")] = foodName.trimmed();
    food[QStringLiteral("category")] = category.trimmed();
    return addItemToMeal(mealIndex, food, amount);
}

static bool isSameFood(const QVariantMap &a, const QVariantMap &b)
{
    // 1. By database ID
    if (a.contains(QStringLiteral("id")) && b.contains(QStringLiteral("id"))) {
        int idA = a.value(QStringLiteral("id")).toInt();
        int idB = b.value(QStringLiteral("id")).toInt();
        if (idA > 0 && idB > 0 && idA == idB) {
            return true;
        }
    }

    // 2. By Barcode
    QString bcA = a.value(QStringLiteral("barcode")).toString().trimmed();
    QString bcB = b.value(QStringLiteral("barcode")).toString().trimmed();
    if (!bcA.isEmpty() && !bcB.isEmpty() && bcA == bcB) {
        return true;
    }

    // 3. By canonical English Name
    QString enA = a.value(QStringLiteral("nameEn")).toString().trimmed();
    QString enB = b.value(QStringLiteral("nameEn")).toString().trimmed();
    if (!enA.isEmpty() && !enB.isEmpty() && enA.compare(enB, Qt::CaseInsensitive) == 0) {
        return true;
    }

    // 4. Cross-check localized names across any language
    const QStringList langKeys = {
        QStringLiteral("name"), QStringLiteral("nameEn"), QStringLiteral("nameDe"),
        QStringLiteral("nameFr"), QStringLiteral("nameEs"), QStringLiteral("nameIt")
    };

    for (const auto &ka : langKeys) {
        QString valA = a.value(ka).toString().trimmed();
        if (valA.isEmpty()) continue;
        for (const auto &kb : langKeys) {
            QString valB = b.value(kb).toString().trimmed();
            if (valB.isEmpty()) continue;
            if (valA.compare(valB, Qt::CaseInsensitive) == 0) {
                return true;
            }
        }
    }

    return false;
}

static double extractNutrient100(const QVariantMap &food, const QString &keyPer100, const QString &rawKey, double curAmt)
{
    if (food.contains(keyPer100) && food.value(keyPer100).toDouble() > 0.0) {
        return food.value(keyPer100).toDouble();
    }
    if (curAmt > 0.0 && curAmt != 100.0 && food.contains(rawKey)) {
        return food.value(rawKey).toDouble() / (curAmt / 100.0);
    }
    return food.value(rawKey, 0.0).toDouble();
}

QVariantMap MealPlanManager::calculateItemNutrition(const QVariantMap &food, double amount)
{
    double grams = (amount <= 0.0) ? 100.0 : amount;
    double factor = grams / 100.0;
    double curAmt = food.value(QStringLiteral("amount")).toDouble();

    // Preserve base nutrient density per 100g so scaling is always linear and non-compounding
    double cal100 = extractNutrient100(food, QStringLiteral("caloriesPer100g"), QStringLiteral("calories"), curAmt);
    double carbs100 = extractNutrient100(food, QStringLiteral("carbsPer100g"), QStringLiteral("carbs"), curAmt);
    double prot100 = extractNutrient100(food, QStringLiteral("proteinPer100g"), QStringLiteral("protein"), curAmt);
    double fat100 = extractNutrient100(food, QStringLiteral("fatPer100g"), QStringLiteral("fat"), curAmt);
    double fib100 = extractNutrient100(food, QStringLiteral("fiberPer100g"), QStringLiteral("fiber"), curAmt);

    // Sub-lipids per 100g
    double satFat100 = extractNutrient100(food, QStringLiteral("satFatPer100g"), QStringLiteral("satFat"), curAmt);
    double mufa100 = extractNutrient100(food, QStringLiteral("mufaPer100g"), QStringLiteral("mufa"), curAmt);
    double pufa100 = extractNutrient100(food, QStringLiteral("pufaPer100g"), QStringLiteral("pufa"), curAmt);
    double o3100 = extractNutrient100(food, QStringLiteral("omega3Per100g"), QStringLiteral("omega3"), curAmt);
    double o6100 = extractNutrient100(food, QStringLiteral("omega6Per100g"), QStringLiteral("omega6"), curAmt);

    // Minerals per 100g
    double ca100 = extractNutrient100(food, QStringLiteral("calciumPer100g"), QStringLiteral("calcium"), curAmt);
    double fe100 = extractNutrient100(food, QStringLiteral("ironPer100g"), QStringLiteral("iron"), curAmt);
    double zn100 = extractNutrient100(food, QStringLiteral("zincPer100g"), QStringLiteral("zinc"), curAmt);
    double cu100 = extractNutrient100(food, QStringLiteral("copperPer100g"), QStringLiteral("copper"), curAmt);
    double mg100 = extractNutrient100(food, QStringLiteral("magnesiumPer100g"), QStringLiteral("magnesium"), curAmt);
    double k100 = extractNutrient100(food, QStringLiteral("potassiumPer100g"), QStringLiteral("potassium"), curAmt);
    double na100 = extractNutrient100(food, QStringLiteral("sodiumPer100g"), QStringLiteral("sodium"), curAmt);

    // Vitamins & Amino Acids per 100g
    double va100 = extractNutrient100(food, QStringLiteral("vitaminAPer100g"), QStringLiteral("vitaminA"), curAmt);
    double vc100 = extractNutrient100(food, QStringLiteral("vitaminCPer100g"), QStringLiteral("vitaminC"), curAmt);
    double vd100 = extractNutrient100(food, QStringLiteral("vitaminDPer100g"), QStringLiteral("vitaminD"), curAmt);
    double ve100 = extractNutrient100(food, QStringLiteral("vitaminEPer100g"), QStringLiteral("vitaminE"), curAmt);
    double vk100 = extractNutrient100(food, QStringLiteral("vitaminKPer100g"), QStringLiteral("vitaminK"), curAmt);
    double thiam100 = extractNutrient100(food, QStringLiteral("thiaminePer100g"), QStringLiteral("thiamine"), curAmt);
    double leu100 = extractNutrient100(food, QStringLiteral("leucinePer100g"), QStringLiteral("leucine"), curAmt);
    double trp100 = extractNutrient100(food, QStringLiteral("tryptophanPer100g"), QStringLiteral("tryptophan"), curAmt);

    // Antinutrients per 100g
    double phy100 = extractNutrient100(food, QStringLiteral("phytateMgPer100g"), QStringLiteral("phytateMg"), curAmt);
    double ox100 = extractNutrient100(food, QStringLiteral("oxalateMgPer100g"), QStringLiteral("oxalateMg"), curAmt);

    QVariantMap item = food;
    item[QStringLiteral("caloriesPer100g")] = cal100;
    item[QStringLiteral("carbsPer100g")] = carbs100;
    item[QStringLiteral("proteinPer100g")] = prot100;
    item[QStringLiteral("fatPer100g")] = fat100;
    item[QStringLiteral("fiberPer100g")] = fib100;

    item[QStringLiteral("satFatPer100g")] = satFat100;
    item[QStringLiteral("mufaPer100g")] = mufa100;
    item[QStringLiteral("pufaPer100g")] = pufa100;
    item[QStringLiteral("omega3Per100g")] = o3100;
    item[QStringLiteral("omega6Per100g")] = o6100;

    item[QStringLiteral("calciumPer100g")] = ca100;
    item[QStringLiteral("ironPer100g")] = fe100;
    item[QStringLiteral("zincPer100g")] = zn100;
    item[QStringLiteral("copperPer100g")] = cu100;
    item[QStringLiteral("magnesiumPer100g")] = mg100;
    item[QStringLiteral("potassiumPer100g")] = k100;
    item[QStringLiteral("sodiumPer100g")] = na100;

    item[QStringLiteral("vitaminAPer100g")] = va100;
    item[QStringLiteral("vitaminCPer100g")] = vc100;
    item[QStringLiteral("vitaminDPer100g")] = vd100;
    item[QStringLiteral("vitaminEPer100g")] = ve100;
    item[QStringLiteral("vitaminKPer100g")] = vk100;
    item[QStringLiteral("thiaminePer100g")] = thiam100;
    item[QStringLiteral("leucinePer100g")] = leu100;
    item[QStringLiteral("tryptophanPer100g")] = trp100;
    item[QStringLiteral("phytateMgPer100g")] = phy100;
    item[QStringLiteral("oxalateMgPer100g")] = ox100;

    item[QStringLiteral("amount")] = grams;

    double servSize = 0.0;
    if (food.contains(QStringLiteral("servingSize"))) {
        servSize = food.value(QStringLiteral("servingSize")).toDouble();
    } else if (food.contains(QStringLiteral("serving_size"))) {
        servSize = food.value(QStringLiteral("serving_size")).toDouble();
    }
    item[QStringLiteral("servingSize")] = servSize;

    QString servUnit = food.contains(QStringLiteral("servingUnit"))
        ? food.value(QStringLiteral("servingUnit")).toString()
        : food.value(QStringLiteral("serving_unit"), food.value(QStringLiteral("unit"), QStringLiteral("g"))).toString();
    item[QStringLiteral("servingUnit")] = servUnit;
    item[QStringLiteral("unit")] = servUnit;

    // Scaled nutrients
    item[QStringLiteral("calories")] = std::round(cal100 * factor * 10.0) / 10.0;
    item[QStringLiteral("carbs")] = std::round(carbs100 * factor * 10.0) / 10.0;
    item[QStringLiteral("protein")] = std::round(prot100 * factor * 10.0) / 10.0;
    item[QStringLiteral("fat")] = std::round(fat100 * factor * 10.0) / 10.0;
    item[QStringLiteral("fiber")] = std::round(fib100 * factor * 10.0) / 10.0;

    item[QStringLiteral("satFat")] = std::round(satFat100 * factor * 100.0) / 100.0;
    item[QStringLiteral("mufa")] = std::round(mufa100 * factor * 100.0) / 100.0;
    item[QStringLiteral("pufa")] = std::round(pufa100 * factor * 100.0) / 100.0;
    item[QStringLiteral("omega3")] = std::round(o3100 * factor * 100.0) / 100.0;
    item[QStringLiteral("omega6")] = std::round(o6100 * factor * 100.0) / 100.0;

    item[QStringLiteral("calcium")] = std::round(ca100 * factor * 10.0) / 10.0;
    item[QStringLiteral("iron")] = std::round(fe100 * factor * 100.0) / 100.0;
    item[QStringLiteral("zinc")] = std::round(zn100 * factor * 100.0) / 100.0;
    item[QStringLiteral("copper")] = std::round(cu100 * factor * 100.0) / 100.0;
    item[QStringLiteral("magnesium")] = std::round(mg100 * factor * 10.0) / 10.0;
    item[QStringLiteral("potassium")] = std::round(k100 * factor * 10.0) / 10.0;
    item[QStringLiteral("sodium")] = std::round(na100 * factor * 10.0) / 10.0;

    item[QStringLiteral("vitaminA")] = std::round(va100 * factor * 10.0) / 10.0;
    item[QStringLiteral("vitaminC")] = std::round(vc100 * factor * 10.0) / 10.0;
    item[QStringLiteral("vitaminD")] = std::round(vd100 * factor * 10.0) / 10.0;
    item[QStringLiteral("vitaminE")] = std::round(ve100 * factor * 10.0) / 10.0;
    item[QStringLiteral("vitaminK")] = std::round(vk100 * factor * 10.0) / 10.0;
    item[QStringLiteral("thiamine")] = std::round(thiam100 * factor * 100.0) / 100.0;
    item[QStringLiteral("leucine")] = std::round(leu100 * factor * 100.0) / 100.0;
    item[QStringLiteral("tryptophan")] = std::round(trp100 * factor * 100.0) / 100.0;

    item[QStringLiteral("phytateMg")] = std::round(phy100 * factor * 10.0) / 10.0;
    item[QStringLiteral("oxalateMg")] = std::round(ox100 * factor * 10.0) / 10.0;

    item[QStringLiteral("icon")] = food.value(QStringLiteral("icon"), QStringLiteral("🥣")).toString();

    return item;
}

bool MealPlanManager::addItemToMeal(int mealIndex, const QVariantMap &food, double amount)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    if (food.isEmpty()) return false;

    QVariantMap meal = m_meals[mealIndex].toMap();
    QVariantList items = meal.value(QStringLiteral("items")).toList();

    int existingItemIdx = -1;
    for (int i = 0; i < items.size(); ++i) {
        QVariantMap it = items[i].toMap();
        if (isSameFood(it, food)) {
            existingItemIdx = i;
            break;
        }
    }

    if (existingItemIdx >= 0) {
        // Merge with existing item by incrementing its portion
        QVariantMap existing = items[existingItemIdx].toMap();
        double curAmt = existing.value(QStringLiteral("amount"), 100.0).toDouble();
        double addAmt = (amount <= 0.0) ? 100.0 : amount;
        double newAmt = curAmt + addAmt;

        // Propagate any newly available metadata or translations
        const QStringList metaKeys = {
            QStringLiteral("id"), QStringLiteral("nameEn"), QStringLiteral("nameDe"),
            QStringLiteral("nameFr"), QStringLiteral("nameEs"), QStringLiteral("nameIt"),
            QStringLiteral("servingSize"), QStringLiteral("servingUnit"),
            QStringLiteral("barcode"), QStringLiteral("icon"), QStringLiteral("category")
        };
        for (const auto &k : metaKeys) {
            if (food.contains(k) && !food.value(k).toString().isEmpty()) {
                existing[k] = food.value(k);
            }
        }
        if (food.contains(QStringLiteral("name")) && !food.value(QStringLiteral("name")).toString().isEmpty()) {
            existing[QStringLiteral("name")] = food.value(QStringLiteral("name"));
        }

        QVariantMap updated = calculateItemNutrition(existing, newAmt);
        items[existingItemIdx] = updated;
        meal[QStringLiteral("items")] = items;
        m_meals[mealIndex] = meal;

        recalculateTotals();
        emit planChanged();
        return true;
    }

    // Append new item
    QVariantMap newItem = calculateItemNutrition(food, amount);
    items.append(newItem);
    meal[QStringLiteral("items")] = items;
    m_meals[mealIndex] = meal;

    recalculateTotals();
    emit planChanged();
    return true;
}

bool MealPlanManager::updateItemAmount(int mealIndex, int itemIndex, double newAmount)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    QVariantMap meal = m_meals[mealIndex].toMap();
    QVariantList items = meal.value(QStringLiteral("items")).toList();
    if (itemIndex < 0 || itemIndex >= items.size()) return false;

    if (newAmount <= 0) {
        return removeItemFromMeal(mealIndex, itemIndex);
    }

    QVariantMap item = items[itemIndex].toMap();
    QVariantMap updated = calculateItemNutrition(item, newAmount);
    items[itemIndex] = updated;
    meal[QStringLiteral("items")] = items;
    m_meals[mealIndex] = meal;

    recalculateTotals();
    emit planChanged();
    return true;
}

bool MealPlanManager::removeItemFromMeal(int mealIndex, int itemIndex)
{
    if (mealIndex < 0 || mealIndex >= m_meals.size()) return false;
    QVariantMap meal = m_meals[mealIndex].toMap();
    QVariantList items = meal.value(QStringLiteral("items")).toList();
    if (itemIndex < 0 || itemIndex >= items.size()) return false;

    items.removeAt(itemIndex);
    meal[QStringLiteral("items")] = items;
    m_meals[mealIndex] = meal;

    recalculateTotals();
    emit planChanged();
    return true;
}

void MealPlanManager::clearPlan()
{
    m_meals.clear();
    recalculateTotals();
    emit planChanged();
}

void MealPlanManager::setMeals(const QVariantList &meals)
{
    m_meals = meals;
    ensureUniqueMealIds(m_meals);
    sortMealsByTime();
    recalculateTotals();
    emit planChanged();
}

QString MealPlanManager::toJsonString() const
{
    QJsonArray arr = QJsonArray::fromVariantList(m_meals);
    QJsonDocument doc(arr);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

bool MealPlanManager::loadFromJsonString(const QString &jsonStr)
{
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        return false;
    }
    m_meals = doc.array().toVariantList();
    ensureUniqueMealIds(m_meals);
    sortMealsByTime();
    recalculateTotals();
    emit planChanged();
    return true;
}

void MealPlanManager::recalculateTotals()
{
    m_totalCalories = 0.0;
    m_totalCarbs = 0.0;
    m_totalProtein = 0.0;
    m_totalFat = 0.0;
    m_totalFiber = 0.0;
    m_totalItemCount = 0;

    m_totalSatFat = 0.0;
    m_totalMufa = 0.0;
    m_totalPufa = 0.0;
    m_totalOmega3 = 0.0;
    m_totalOmega6 = 0.0;
    m_totalCalcium = 0.0;
    m_totalIron = 0.0;
    m_totalZinc = 0.0;
    m_totalCopper = 0.0;
    m_totalMagnesium = 0.0;
    m_totalPotassium = 0.0;
    m_totalSodium = 0.0;
    m_totalVitaminA = 0.0;
    m_totalVitaminC = 0.0;
    m_totalVitaminD = 0.0;
    m_totalVitaminE = 0.0;
    m_totalVitaminK = 0.0;
    m_totalThiamine = 0.0;
    m_totalLeucine = 0.0;
    m_totalTryptophan = 0.0;
    m_totalPhytateMg = 0.0;
    m_totalOxalateMg = 0.0;

    m_totalWorkoutCalories = 0.0;
    m_totalWorkoutCarbs = 0.0;
    m_totalWorkoutProtein = 0.0;
    m_totalWorkoutFat = 0.0;
    m_workoutCount = 0;

    for (int m = 0; m < m_meals.size(); ++m) {
        QVariantMap meal = m_meals[m].toMap();

        if (meal.value(QStringLiteral("isWorkout")).toBool()) {
            m_workoutCount++;
            m_totalWorkoutCalories += meal.value(QStringLiteral("calories")).toDouble();
            m_totalWorkoutCarbs += meal.value(QStringLiteral("carbs")).toDouble();
            m_totalWorkoutProtein += meal.value(QStringLiteral("protein")).toDouble();
            m_totalWorkoutFat += meal.value(QStringLiteral("fat")).toDouble();
            continue;
        }

        QVariantList items = meal.value(QStringLiteral("items")).toList();

        double mCal = 0.0;
        double mCarb = 0.0;
        double mProt = 0.0;
        double mFat = 0.0;
        double mFib = 0.0;

        double mSatFat = 0.0;
        double mMufa = 0.0;
        double mPufa = 0.0;
        double mO3 = 0.0;
        double mO6 = 0.0;

        double mCa = 0.0;
        double mFe = 0.0;
        double mNonHemeFe = 0.0;
        double mHemeFe = 0.0;
        double mZn = 0.0;
        double mCu = 0.0;
        double mMg = 0.0;
        double mK = 0.0;
        double mNa = 0.0;

        double mVa = 0.0;
        double mVc = 0.0;
        double mVd = 0.0;
        double mVe = 0.0;
        double mVk = 0.0;
        double mThiam = 0.0;
        double mLeu = 0.0;
        double mTrp = 0.0;

        double mPhy = 0.0;
        double mOx = 0.0;

        bool hasPhosvitin = false;
        bool containsCaffeine = false;
        bool isViscousFiber = false;
        bool hasDairyCalcium = false;
        double maxGastricHours = 0.0;
        QString maxGI = QStringLiteral("low");

        for (const auto &it : items) {
            QVariantMap itemMap = it.toMap();
            mCal += itemMap.value(QStringLiteral("calories")).toDouble();
            mCarb += itemMap.value(QStringLiteral("carbs")).toDouble();
            mProt += itemMap.value(QStringLiteral("protein")).toDouble();
            mFat += itemMap.value(QStringLiteral("fat")).toDouble();
            mFib += itemMap.value(QStringLiteral("fiber")).toDouble();

            mSatFat += itemMap.value(QStringLiteral("satFat")).toDouble();
            mMufa += itemMap.value(QStringLiteral("mufa")).toDouble();
            mPufa += itemMap.value(QStringLiteral("pufa")).toDouble();
            mO3 += itemMap.value(QStringLiteral("omega3")).toDouble();
            mO6 += itemMap.value(QStringLiteral("omega6")).toDouble();

            double fe = itemMap.value(QStringLiteral("iron")).toDouble();
            mFe += fe;
            QString feType = itemMap.value(QStringLiteral("ironType"), QStringLiteral("none")).toString();
            if (feType == QStringLiteral("non_heme")) {
                mNonHemeFe += fe;
            } else if (feType == QStringLiteral("heme")) {
                mHemeFe += fe;
            } else {
                mNonHemeFe += fe; // default plant iron
            }

            mCa += itemMap.value(QStringLiteral("calcium")).toDouble();
            mZn += itemMap.value(QStringLiteral("zinc")).toDouble();
            mCu += itemMap.value(QStringLiteral("copper")).toDouble();
            mMg += itemMap.value(QStringLiteral("magnesium")).toDouble();
            mK += itemMap.value(QStringLiteral("potassium")).toDouble();
            mNa += itemMap.value(QStringLiteral("sodium")).toDouble();

            mVa += itemMap.value(QStringLiteral("vitaminA")).toDouble();
            mVc += itemMap.value(QStringLiteral("vitaminC")).toDouble();
            mVd += itemMap.value(QStringLiteral("vitaminD")).toDouble();
            mVe += itemMap.value(QStringLiteral("vitaminE")).toDouble();
            mVk += itemMap.value(QStringLiteral("vitaminK")).toDouble();
            mThiam += itemMap.value(QStringLiteral("thiamine")).toDouble();
            mLeu += itemMap.value(QStringLiteral("leucine")).toDouble();
            mTrp += itemMap.value(QStringLiteral("tryptophan")).toDouble();

            mPhy += itemMap.value(QStringLiteral("phytateMg")).toDouble();
            mOx += itemMap.value(QStringLiteral("oxalateMg")).toDouble();

            if (itemMap.value(QStringLiteral("hasPhosvitin")).toInt() == 1) hasPhosvitin = true;
            if (itemMap.value(QStringLiteral("containsCaffeine")).toInt() == 1 || itemMap.value(QStringLiteral("polyphenolLevel")).toInt() >= 1) containsCaffeine = true;
            if (itemMap.value(QStringLiteral("isViscousFiber")).toInt() == 1) isViscousFiber = true;
            if (itemMap.value(QStringLiteral("isDairyCalcium")).toInt() == 1) hasDairyCalcium = true;

            double gHours = itemMap.value(QStringLiteral("gastricEmptyingHours")).toDouble();
            if (gHours > maxGastricHours) maxGastricHours = gHours;

            QString gi = itemMap.value(QStringLiteral("giClass")).toString().toLower();
            if (gi == QStringLiteral("high")) {
                maxGI = QStringLiteral("high");
            } else if (gi == QStringLiteral("medium") && maxGI != QStringLiteral("high")) {
                maxGI = QStringLiteral("medium");
            }

            m_totalItemCount++;
        }

        meal[QStringLiteral("calories")] = std::round(mCal * 10.0) / 10.0;
        meal[QStringLiteral("carbs")] = std::round(mCarb * 10.0) / 10.0;
        meal[QStringLiteral("protein")] = std::round(mProt * 10.0) / 10.0;
        meal[QStringLiteral("fat")] = std::round(mFat * 10.0) / 10.0;
        meal[QStringLiteral("fiber")] = std::round(mFib * 10.0) / 10.0;

        meal[QStringLiteral("satFat")] = std::round(mSatFat * 10.0) / 10.0;
        meal[QStringLiteral("mufa")] = std::round(mMufa * 10.0) / 10.0;
        meal[QStringLiteral("pufa")] = std::round(mPufa * 10.0) / 10.0;
        meal[QStringLiteral("omega3")] = std::round(mO3 * 100.0) / 100.0;
        meal[QStringLiteral("omega6")] = std::round(mO6 * 100.0) / 100.0;

        meal[QStringLiteral("calcium")] = std::round(mCa * 10.0) / 10.0;
        meal[QStringLiteral("iron")] = std::round(mFe * 100.0) / 100.0;
        meal[QStringLiteral("nonHemeIron")] = std::round(mNonHemeFe * 100.0) / 100.0;
        meal[QStringLiteral("hemeIron")] = std::round(mHemeFe * 100.0) / 100.0;
        meal[QStringLiteral("zinc")] = std::round(mZn * 100.0) / 100.0;
        meal[QStringLiteral("copper")] = std::round(mCu * 100.0) / 100.0;
        meal[QStringLiteral("magnesium")] = std::round(mMg * 10.0) / 10.0;
        meal[QStringLiteral("potassium")] = std::round(mK * 10.0) / 10.0;
        meal[QStringLiteral("sodium")] = std::round(mNa * 10.0) / 10.0;

        meal[QStringLiteral("vitaminA")] = std::round(mVa * 10.0) / 10.0;
        meal[QStringLiteral("vitaminC")] = std::round(mVc * 10.0) / 10.0;
        meal[QStringLiteral("vitaminD")] = std::round(mVd * 10.0) / 10.0;
        meal[QStringLiteral("vitaminE")] = std::round(mVe * 10.0) / 10.0;
        meal[QStringLiteral("vitaminK")] = std::round(mVk * 10.0) / 10.0;
        meal[QStringLiteral("thiamine")] = std::round(mThiam * 100.0) / 100.0;
        meal[QStringLiteral("leucine")] = std::round(mLeu * 100.0) / 100.0;
        meal[QStringLiteral("tryptophan")] = std::round(mTrp * 100.0) / 100.0;

        meal[QStringLiteral("phytateMg")] = std::round(mPhy * 10.0) / 10.0;
        meal[QStringLiteral("oxalateMg")] = std::round(mOx * 10.0) / 10.0;

        meal[QStringLiteral("hasPhosvitin")] = hasPhosvitin;
        meal[QStringLiteral("containsCaffeine")] = containsCaffeine;
        meal[QStringLiteral("isViscousFiber")] = isViscousFiber;
        meal[QStringLiteral("hasDairyCalcium")] = hasDairyCalcium;
        meal[QStringLiteral("gastricEmptyingHours")] = maxGastricHours;
        meal[QStringLiteral("giClass")] = maxGI;

        m_meals[m] = meal;

        m_totalCalories += mCal;
        m_totalCarbs += mCarb;
        m_totalProtein += mProt;
        m_totalFat += mFat;
        m_totalFiber += mFib;

        m_totalSatFat += mSatFat;
        m_totalMufa += mMufa;
        m_totalPufa += mPufa;
        m_totalOmega3 += mO3;
        m_totalOmega6 += mO6;

        m_totalCalcium += mCa;
        m_totalIron += mFe;
        m_totalZinc += mZn;
        m_totalCopper += mCu;
        m_totalMagnesium += mMg;
        m_totalPotassium += mK;
        m_totalSodium += mNa;

        m_totalVitaminA += mVa;
        m_totalVitaminC += mVc;
        m_totalVitaminD += mVd;
        m_totalVitaminE += mVe;
        m_totalVitaminK += mVk;
        m_totalThiamine += mThiam;
        m_totalLeucine += mLeu;
        m_totalTryptophan += mTrp;

        m_totalPhytateMg += mPhy;
        m_totalOxalateMg += mOx;
    }

    m_totalCalories = std::round(m_totalCalories * 10.0) / 10.0;
    m_totalCarbs = std::round(m_totalCarbs * 10.0) / 10.0;
    m_totalProtein = std::round(m_totalProtein * 10.0) / 10.0;
    m_totalFat = std::round(m_totalFat * 10.0) / 10.0;
    m_totalFiber = std::round(m_totalFiber * 10.0) / 10.0;

    m_totalSatFat = std::round(m_totalSatFat * 10.0) / 10.0;
    m_totalMufa = std::round(m_totalMufa * 10.0) / 10.0;
    m_totalPufa = std::round(m_totalPufa * 10.0) / 10.0;
    m_totalOmega3 = std::round(m_totalOmega3 * 100.0) / 100.0;
    m_totalOmega6 = std::round(m_totalOmega6 * 100.0) / 100.0;

    m_totalCalcium = std::round(m_totalCalcium * 10.0) / 10.0;
    m_totalIron = std::round(m_totalIron * 100.0) / 100.0;
    m_totalZinc = std::round(m_totalZinc * 100.0) / 100.0;
    m_totalCopper = std::round(m_totalCopper * 100.0) / 100.0;
    m_totalMagnesium = std::round(m_totalMagnesium * 10.0) / 10.0;
    m_totalPotassium = std::round(m_totalPotassium * 10.0) / 10.0;
    m_totalSodium = std::round(m_totalSodium * 10.0) / 10.0;

    m_totalVitaminA = std::round(m_totalVitaminA * 10.0) / 10.0;
    m_totalVitaminC = std::round(m_totalVitaminC * 10.0) / 10.0;
    m_totalVitaminD = std::round(m_totalVitaminD * 10.0) / 10.0;
    m_totalVitaminE = std::round(m_totalVitaminE * 10.0) / 10.0;
    m_totalVitaminK = std::round(m_totalVitaminK * 10.0) / 10.0;
    m_totalThiamine = std::round(m_totalThiamine * 100.0) / 100.0;
    m_totalLeucine = std::round(m_totalLeucine * 100.0) / 100.0;
    m_totalTryptophan = std::round(m_totalTryptophan * 100.0) / 100.0;

    m_totalPhytateMg = std::round(m_totalPhytateMg * 10.0) / 10.0;
    m_totalOxalateMg = std::round(m_totalOxalateMg * 10.0) / 10.0;

    // Standard Atwater energy: Carbs 4 kcal/g, Protein 4 kcal/g, Fat 9 kcal/g
    double macroEnergy = (m_totalCarbs * 4.0) + (m_totalProtein * 4.0) + (m_totalFat * 9.0);
    if (macroEnergy > 0.1) {
        m_carbPercent = std::round((m_totalCarbs * 4.0 / macroEnergy) * 1000.0) / 10.0;
        m_proteinPercent = std::round((m_totalProtein * 4.0 / macroEnergy) * 1000.0) / 10.0;
        m_fatPercent = std::round((m_totalFat * 9.0 / macroEnergy) * 1000.0) / 10.0;
    } else {
        m_carbPercent = 0.0;
        m_proteinPercent = 0.0;
        m_fatPercent = 0.0;
    }

    m_targetCalories = m_baseCalories + m_totalWorkoutCalories;
}

void MealPlanManager::loadGoldenPlan(QObject *foodDbObj)
{
    clearPlan();

    FoodDatabase *foodDb = qobject_cast<FoodDatabase*>(foodDbObj);
    FoodDatabase localDb;
    if (!foodDb) {
        localDb.initDatabase();
        foodDb = &localDb;
    }

    auto fetchOrMake = [&](int id, const QString &nameEn, const QString &nameDe, double cals, double carbs, double prot, double fat, double fib, double serv, const QString &icon) -> QVariantMap {
        QVariantMap f = foodDb ? foodDb->getFoodById(id) : QVariantMap();
        if (!f.isEmpty() && f.value(QStringLiteral("id")).toInt() == id && f.value(QStringLiteral("calories")).toDouble() > 0.0) {
            return f;
        }
        // Fallback
        f[QStringLiteral("id")] = id;
        f[QStringLiteral("name")] = nameEn;
        f[QStringLiteral("nameEn")] = nameEn;
        f[QStringLiteral("nameDe")] = nameDe;
        f[QStringLiteral("calories")] = cals;
        f[QStringLiteral("carbs")] = carbs;
        f[QStringLiteral("protein")] = prot;
        f[QStringLiteral("fat")] = fat;
        f[QStringLiteral("fiber")] = fib;
        f[QStringLiteral("servingSize")] = serv;
        f[QStringLiteral("servingUnit")] = QStringLiteral("g");
        f[QStringLiteral("icon")] = icon;
        return f;
    };

    // Baseline Profile for Golden Plan
    m_baseCalories = 2000.0;
    m_userSport = QStringLiteral("endurance_power");

    // Meal 1: Breakfast (07:30) - Front-loaded Calcium (>60% daily Ca)
    int m1 = addMeal(QStringLiteral("Breakfast"), QStringLiteral("07:30"), QStringLiteral("🥣"), QStringLiteral("#F59E0B"));
    addItemToMeal(m1, fetchOrMake(1, QStringLiteral("Oats"), QStringLiteral("Haferflocken"), 389, 66.3, 16.9, 6.9, 10.6, 80, QStringLiteral("🥣")), 95);
    addItemToMeal(m1, fetchOrMake(26, QStringLiteral("Yogurt"), QStringLiteral("Naturjogurt"), 63, 7.05, 5.25, 1.55, 0.0, 150, QStringLiteral("🥛")), 240);
    addItemToMeal(m1, fetchOrMake(73, QStringLiteral("Apple"), QStringLiteral("Apfel"), 52, 13.8, 0.26, 0.17, 2.4, 150, QStringLiteral("🍎")), 120);
    addItemToMeal(m1, fetchOrMake(88, QStringLiteral("Walnut"), QStringLiteral("Walnüsse"), 654, 13.7, 15.2, 65.2, 6.7, 20, QStringLiteral("🥜")), 14);

    // Meal 2: Lunch (13:00) - Primary Fe Meal (Ca <= 125mg, zero dairy/phosvitin, 110g Bell Pepper for Vit C)
    int m2 = addMeal(QStringLiteral("Lunch"), QStringLiteral("13:00"), QStringLiteral("🥗"), QStringLiteral("#10B981"));
    addItemToMeal(m2, fetchOrMake(36, QStringLiteral("Beef"), QStringLiteral("Rindfleisch"), 197, 0.0, 18.6, 13.1, 0.0, 120, QStringLiteral("🥩")), 45);
    addItemToMeal(m2, fetchOrMake(16, QStringLiteral("Sweet potato"), QStringLiteral("Süßkartoffel"), 86, 20.1, 1.57, 0.05, 3.0, 200, QStringLiteral("🍠")), 200);
    addItemToMeal(m2, fetchOrMake(51, QStringLiteral("Bell pepper"), QStringLiteral("Paprika"), 26, 6.0, 0.99, 0.3, 2.1, 100, QStringLiteral("🫑")), 110);
    addItemToMeal(m2, fetchOrMake(48, QStringLiteral("Zucchini"), QStringLiteral("Zucchini"), 17, 3.1, 1.2, 0.32, 1.0, 150, QStringLiteral("🥒")), 120);
    addItemToMeal(m2, fetchOrMake(91, QStringLiteral("Olive oil"), QStringLiteral("Olivenöl"), 884, 0.0, 0.0, 100.0, 0.0, 10, QStringLiteral("🫒")), 21);

    // Meal 3: Post-Workout (18:00) - Rapid PepT1 surge (20g+ protein + fast carbs)
    int m3 = addMeal(QStringLiteral("Post-Workout"), QStringLiteral("18:00"), QStringLiteral("⚡"), QStringLiteral("#3B82F6"));
    addItemToMeal(m3, fetchOrMake(33, QStringLiteral("Whey protein"), QStringLiteral("Whey Protein"), 370, 3.0, 82.0, 1.5, 0.0, 28, QStringLiteral("🥤")), 22);
    addItemToMeal(m3, fetchOrMake(75, QStringLiteral("Banana"), QStringLiteral("Banane"), 89, 22.8, 1.09, 0.33, 2.6, 120, QStringLiteral("🍌")), 190);

    // Meal 4: Dinner (19:45) - Evening Magnesium Window (>50% Mg), high EPA/DHA Omega-3, LAT1 Trp
    int m4 = addMeal(QStringLiteral("Dinner"), QStringLiteral("19:45"), QStringLiteral("🍲"), QStringLiteral("#8B5CF6"));
    addItemToMeal(m4, fetchOrMake(38, QStringLiteral("Salmon"), QStringLiteral("Lachs"), 182, 0.0, 22.5, 9.6, 0.0, 130, QStringLiteral("🐟")), 95);
    addItemToMeal(m4, fetchOrMake(115, QStringLiteral("Spelt"), QStringLiteral("Dinkel"), 127, 26.4, 5.5, 0.85, 3.9, 70, QStringLiteral("🌾")), 205);
    addItemToMeal(m4, fetchOrMake(43, QStringLiteral("Broccoli"), QStringLiteral("Broccoli"), 34, 6.64, 2.82, 0.37, 2.6, 150, QStringLiteral("🥦")), 130);
    addItemToMeal(m4, fetchOrMake(90, QStringLiteral("Pumpkin seed"), QStringLiteral("Kürbiskerne"), 559, 10.7, 30.2, 49.1, 6.0, 20, QStringLiteral("🌱")), 22);

    recalculateTotals();
    emit userProfileChanged();
    emit planChanged();
}

static QString translateMealTitle(const QString &currentTitle, const QString &targetLang)
{
    struct MealTitleTrans {
        const char *en;
        const char *de;
        const char *fr;
        const char *es;
        const char *it;
    };
    static const MealTitleTrans titles[] = {
        { "Breakfast", "Frühstück", "Petit-déjeuner", "Desayuno", "Colazione" },
        { "Lunch", "Mittagessen", "Déjeuner", "Almuerzo", "Pranzo" },
        { "Afternoon Snack", "Nachmittagssnack", "Goûter", "Merienda", "Merenda" },
        { "Snack", "Snack", "Collation", "Tentempié", "Spuntino" },
        { "Dinner", "Abendessen", "Dîner", "Cena", "Cena" }
    };

    QString t = currentTitle.trimmed();
    for (const auto &row : titles) {
        if (t.compare(QLatin1String(row.en), Qt::CaseInsensitive) == 0 ||
            t.compare(QLatin1String(row.de), Qt::CaseInsensitive) == 0 ||
            t.compare(QLatin1String(row.fr), Qt::CaseInsensitive) == 0 ||
            t.compare(QLatin1String(row.es), Qt::CaseInsensitive) == 0 ||
            t.compare(QLatin1String(row.it), Qt::CaseInsensitive) == 0) {
            if (targetLang == QLatin1String("de")) return QString::fromUtf8(row.de);
            if (targetLang == QLatin1String("fr")) return QString::fromUtf8(row.fr);
            if (targetLang == QLatin1String("es")) return QString::fromUtf8(row.es);
            if (targetLang == QLatin1String("it")) return QString::fromUtf8(row.it);
            return QString::fromUtf8(row.en);
        }
    }
    return currentTitle;
}

void MealPlanManager::loadEmptyPlan()
{
    m_meals.clear();
    addMeal(QStringLiteral("Food"), QStringLiteral("12:00"), QStringLiteral("🍽️"), QStringLiteral("#3B82F6"));
}

void MealPlanManager::loadSamplePlan()
{
    m_meals.clear();

    auto makeFood = [](int id, const QString &en, const QString &de, const QString &fr, const QString &es, const QString &it,
                       double cal, double carbs, double prot, double fat, double fib,
                       double servingSize, const QString &unit, const QString &icon, const QString &barcode = QString()) {
        QVariantMap f;
        f[QStringLiteral("id")] = id;
        f[QStringLiteral("name")] = en;
        f[QStringLiteral("nameEn")] = en;
        f[QStringLiteral("nameDe")] = de;
        f[QStringLiteral("nameFr")] = fr;
        f[QStringLiteral("nameEs")] = es;
        f[QStringLiteral("nameIt")] = it;
        f[QStringLiteral("calories")] = cal;
        f[QStringLiteral("carbs")] = carbs;
        f[QStringLiteral("protein")] = prot;
        f[QStringLiteral("fat")] = fat;
        f[QStringLiteral("fiber")] = fib;
        f[QStringLiteral("caloriesPer100g")] = cal;
        f[QStringLiteral("carbsPer100g")] = carbs;
        f[QStringLiteral("proteinPer100g")] = prot;
        f[QStringLiteral("fatPer100g")] = fat;
        f[QStringLiteral("fiberPer100g")] = fib;
        f[QStringLiteral("servingSize")] = servingSize;
        f[QStringLiteral("servingUnit")] = unit;
        f[QStringLiteral("unit")] = unit;
        f[QStringLiteral("icon")] = icon;
        f[QStringLiteral("barcode")] = barcode;
        return f;
    };

    // 1. Breakfast (08:00)
    int bIndex = addMeal(QStringLiteral("Breakfast"), QStringLiteral("08:00"), QStringLiteral("🍳"), QStringLiteral("#F59E0B"));
    addItemToMeal(bIndex, makeFood(1, QStringLiteral("Rolled Oats"), QStringLiteral("Haferflocken"), QStringLiteral("Flocons d'avoine"), QStringLiteral("Copos de avena"), QStringLiteral("Fiocchi d'avena"), 379, 67.7, 13.2, 6.5, 10.1, 80, QStringLiteral("g"), QStringLiteral("🥣"), QStringLiteral("4008400404127")), 70);
    addItemToMeal(bIndex, makeFood(31, QStringLiteral("Fresh Banana"), QStringLiteral("Frische Banane"), QStringLiteral("Banane fraîche"), QStringLiteral("Plátano fresco"), QStringLiteral("Banana fresca"), 89, 22.8, 1.1, 0.3, 2.6, 120, QStringLiteral("g"), QStringLiteral("🍌")), 120);
    addItemToMeal(bIndex, makeFood(53, QStringLiteral("Whole Milk (3.25%)"), QStringLiteral("Vollmilch (3,5%)"), QStringLiteral("Lait entier"), QStringLiteral("Leche entera"), QStringLiteral("Latte intero"), 61, 4.8, 3.2, 3.3, 0.0, 240, QStringLiteral("ml"), QStringLiteral("🥛")), 200);

    // 2. Lunch (12:30)
    int lIndex = addMeal(QStringLiteral("Lunch"), QStringLiteral("12:30"), QStringLiteral("🥗"), QStringLiteral("#10B981"));
    addItemToMeal(lIndex, makeFood(11, QStringLiteral("Chicken Breast (Grilled)"), QStringLiteral("Hähnchenbrust (gegrillt)"), QStringLiteral("Blanc de poulet (grillé)"), QStringLiteral("Pechuga de pollo (plancha)"), QStringLiteral("Petto di pollo (griglia)"), 165, 0.0, 31.0, 3.6, 0.0, 150, QStringLiteral("g"), QStringLiteral("🍗")), 160);
    addItemToMeal(lIndex, makeFood(4, QStringLiteral("Jasmine Rice (Cooked)"), QStringLiteral("Jasminreis (gekocht)"), QStringLiteral("Riz jasmin (cuit)"), QStringLiteral("Arroz jazmín (cocido)"), QStringLiteral("Riso jasmine (cotto)"), 130, 28.2, 2.7, 0.3, 0.4, 150, QStringLiteral("g"), QStringLiteral("🍚")), 180);
    addItemToMeal(lIndex, makeFood(22, QStringLiteral("Broccoli Florets"), QStringLiteral("Brokkoli-Röschen"), QStringLiteral("Fleurettes de brocoli"), QStringLiteral("Floretes de brócoli"), QStringLiteral("Cime di broccoli"), 34, 6.6, 2.8, 0.4, 2.6, 120, QStringLiteral("g"), QStringLiteral("🥦")), 150);
    addItemToMeal(lIndex, makeFood(47, QStringLiteral("Extra Virgin Olive Oil"), QStringLiteral("Natives Olivenöl Extra"), QStringLiteral("Huile d'olive vierge extra"), QStringLiteral("Aceite de oliva virgen extra"), QStringLiteral("Olio extravergine d'oliva"), 884, 0.0, 0.0, 100.0, 0.0, 15, QStringLiteral("ml"), QStringLiteral("🫒")), 10);

    // 3. Afternoon Snack (16:30)
    int sIndex = addMeal(QStringLiteral("Afternoon Snack"), QStringLiteral("16:30"), QStringLiteral("🍎"), QStringLiteral("#EC4899"));
    addItemToMeal(sIndex, makeFood(32, QStringLiteral("Honeycrisp Apple"), QStringLiteral("Apfel (Honeycrisp)"), QStringLiteral("Pomme"), QStringLiteral("Manzana"), QStringLiteral("Mela"), 52, 13.8, 0.3, 0.2, 2.4, 150, QStringLiteral("g"), QStringLiteral("🍎")), 150);
    addItemToMeal(sIndex, makeFood(44, QStringLiteral("Raw Almonds"), QStringLiteral("Mandeln (roh)"), QStringLiteral("Amandes crues"), QStringLiteral("Almendras crudas"), QStringLiteral("Mandorle crude"), 579, 21.6, 21.2, 49.9, 12.5, 30, QStringLiteral("g"), QStringLiteral("🥜")), 25);

    // 4. Dinner (19:30)
    int dIndex = addMeal(QStringLiteral("Dinner"), QStringLiteral("19:30"), QStringLiteral("🍲"), QStringLiteral("#8B5CF6"));
    addItemToMeal(dIndex, makeFood(13, QStringLiteral("Atlantic Salmon (Baked)"), QStringLiteral("Lachsfilet (gebacken)"), QStringLiteral("Saumon atlantique (cuit)"), QStringLiteral("Salmón atlántico (horno)"), QStringLiteral("Salmone atlantico (forno)"), 208, 0.0, 22.1, 12.3, 0.0, 140, QStringLiteral("g"), QStringLiteral("🐟")), 140);
    addItemToMeal(dIndex, makeFood(7, QStringLiteral("Baked Sweet Potato"), QStringLiteral("Gebackene Süßkartoffel"), QStringLiteral("Patate douce au four"), QStringLiteral("Batata asada"), QStringLiteral("Patata dolce al forno"), 90, 20.7, 2.0, 0.1, 3.3, 180, QStringLiteral("g"), QStringLiteral("🍠")), 180);
    addItemToMeal(dIndex, makeFood(21, QStringLiteral("Baby Spinach"), QStringLiteral("Babyspinat"), QStringLiteral("Jeunes pousses d'épinard"), QStringLiteral("Espinacas baby"), QStringLiteral("Spinaci novelli"), 23, 3.6, 2.9, 0.4, 2.2, 80, QStringLiteral("g"), QStringLiteral("🥬")), 100);

    recalculateTotals();
    emit planChanged();
}

QString MealPlanManager::toYamlString() const
{
    QString yaml;
    yaml += QStringLiteral("version: \"1.0\"\n");
    yaml += QStringLiteral("title: \"Day Meal Plan (%1 / %2 kcal)\"\n\n")
                .arg(static_cast<int>(std::round(m_totalCalories)))
                .arg(static_cast<int>(std::round(m_targetCalories)));
    yaml += QStringLiteral("plan:\n");

    for (const auto &mVal : m_meals) {
        QVariantMap meal = mVal.toMap();
        QString title = meal.value(QStringLiteral("title")).toString();
        QString time = meal.value(QStringLiteral("time")).toString();
        QString icon = meal.value(QStringLiteral("icon")).toString();
        QString color = meal.value(QStringLiteral("color")).toString();
        double cal = meal.value(QStringLiteral("calories")).toDouble();
        bool isWorkout = meal.value(QStringLiteral("isWorkout")).toBool();

        if (isWorkout) {
            int duration = meal.value(QStringLiteral("duration"), 60).toInt();
            int durH = duration / 60;
            int durM = duration % 60;
            QString durStr = QStringLiteral("%1:%2")
                                .arg(durH, 2, 10, QChar('0'))
                                .arg(durM, 2, 10, QChar('0'));
            yaml += QStringLiteral("  - title: \"%1 (-%2 kcal)\"\n").arg(title).arg(static_cast<int>(std::round(cal)));
            yaml += QStringLiteral("    start: \"%1\"\n").arg(time);
            yaml += QStringLiteral("    duration: \"%1\"\n").arg(durStr);
            yaml += QStringLiteral("    icon: \"%1\"\n").arg(icon);
            yaml += QStringLiteral("    color: \"%1\"\n").arg(color);
            yaml += QStringLiteral("    items:\n");
            yaml += QStringLiteral("      - title: \"Expenditure: %1 kcal (C:%2g, P:%3g, F:%4g)\"\n")
                        .arg(static_cast<int>(std::round(cal)))
                        .arg(meal.value(QStringLiteral("carbs")).toDouble(), 0, 'f', 1)
                        .arg(meal.value(QStringLiteral("protein")).toDouble(), 0, 'f', 1)
                        .arg(meal.value(QStringLiteral("fat")).toDouble(), 0, 'f', 1);
            yaml += QStringLiteral("        icon: \"🔥\"\n\n");
            continue;
        }

        yaml += QStringLiteral("  - title: \"%1 (%2 kcal)\"\n").arg(title).arg(static_cast<int>(std::round(cal)));
        yaml += QStringLiteral("    start: \"%1\"\n").arg(time);
        yaml += QStringLiteral("    duration: \"00:45\"\n");
        yaml += QStringLiteral("    icon: \"%1\"\n").arg(icon);
        yaml += QStringLiteral("    color: \"%1\"\n").arg(color);

        QVariantList items = meal.value(QStringLiteral("items")).toList();
        if (!items.isEmpty()) {
            yaml += QStringLiteral("    items:\n");
            for (const auto &iVal : items) {
                QVariantMap item = iVal.toMap();
                QString iName = item.value(QStringLiteral("name")).toString();
                double amount = item.value(QStringLiteral("amount")).toDouble();
                QString unit = item.value(QStringLiteral("unit")).toString();
                double iCal = item.value(QStringLiteral("calories")).toDouble();
                QString iIcon = item.value(QStringLiteral("icon")).toString();

                yaml += QStringLiteral("      - title: \"%1 (%2%3 - %4 kcal)\"\n")
                            .arg(iName)
                            .arg(amount)
                            .arg(unit)
                            .arg(static_cast<int>(std::round(iCal)));
                yaml += QStringLiteral("        icon: \"%1\"\n").arg(iIcon);
            }
        }
        yaml += QStringLiteral("\n");
    }

    return yaml;
}

void MealPlanManager::syncToDayPlanModel(QObject *dayPlanModelObj)
{
    if (!dayPlanModelObj) return;
    QString yaml = toYamlString();
    QMetaObject::invokeMethod(dayPlanModelObj, "loadYaml",
                             Q_ARG(QString, yaml));
}

void MealPlanManager::updateLanguage(const QString &langCode, QObject *foodDbObj)
{
    QString code = langCode.trimmed().toLower();
    bool anyChanged = false;

    FoodDatabase *fdb = qobject_cast<FoodDatabase*>(foodDbObj);

    for (int m = 0; m < m_meals.size(); ++m) {
        QVariantMap meal = m_meals[m].toMap();
        QString oldTitle = meal.value(QStringLiteral("title")).toString();
        QString newTitle = translateMealTitle(oldTitle, code);
        if (newTitle != oldTitle) {
            meal[QStringLiteral("title")] = newTitle;
            anyChanged = true;
        }

        QVariantList items = meal.value(QStringLiteral("items")).toList();
        bool mealItemsChanged = false;

        for (int i = 0; i < items.size(); ++i) {
            QVariantMap item = items[i].toMap();
            QString newName;

            if (code == QStringLiteral("de") && item.contains(QStringLiteral("nameDe")) && !item.value(QStringLiteral("nameDe")).toString().isEmpty()) {
                newName = item.value(QStringLiteral("nameDe")).toString();
            } else if (code == QStringLiteral("fr") && item.contains(QStringLiteral("nameFr")) && !item.value(QStringLiteral("nameFr")).toString().isEmpty()) {
                newName = item.value(QStringLiteral("nameFr")).toString();
            } else if (code == QStringLiteral("es") && item.contains(QStringLiteral("nameEs")) && !item.value(QStringLiteral("nameEs")).toString().isEmpty()) {
                newName = item.value(QStringLiteral("nameEs")).toString();
            } else if (code == QStringLiteral("it") && item.contains(QStringLiteral("nameIt")) && !item.value(QStringLiteral("nameIt")).toString().isEmpty()) {
                newName = item.value(QStringLiteral("nameIt")).toString();
            } else if (code == QStringLiteral("en") && item.contains(QStringLiteral("nameEn")) && !item.value(QStringLiteral("nameEn")).toString().isEmpty()) {
                newName = item.value(QStringLiteral("nameEn")).toString();
            }

            // Fallback 1: check food database by id if available
            if (newName.isEmpty() && fdb && item.contains(QStringLiteral("id"))) {
                int foodId = item.value(QStringLiteral("id")).toInt();
                if (foodId > 0) {
                    QVariantMap info = fdb->getFoodById(foodId, code);
                    if (!info.isEmpty()) {
                        newName = info.value(QStringLiteral("name")).toString();
                        if (!item.contains(QStringLiteral("nameEn"))) item[QStringLiteral("nameEn")] = info.value(QStringLiteral("nameEn"));
                        if (!item.contains(QStringLiteral("nameDe"))) item[QStringLiteral("nameDe")] = info.value(QStringLiteral("nameDe"));
                        if (!item.contains(QStringLiteral("nameFr"))) item[QStringLiteral("nameFr")] = info.value(QStringLiteral("nameFr"));
                        if (!item.contains(QStringLiteral("nameEs"))) item[QStringLiteral("nameEs")] = info.value(QStringLiteral("nameEs"));
                        if (!item.contains(QStringLiteral("nameIt"))) item[QStringLiteral("nameIt")] = info.value(QStringLiteral("nameIt"));
                        if (!item.contains(QStringLiteral("servingSize")) || item.value(QStringLiteral("servingSize")).toDouble() <= 0) {
                            item[QStringLiteral("servingSize")] = info.value(QStringLiteral("servingSize"));
                        }
                        if (!item.contains(QStringLiteral("servingUnit")) || item.value(QStringLiteral("servingUnit")).toString().isEmpty()) {
                            item[QStringLiteral("servingUnit")] = info.value(QStringLiteral("servingUnit"));
                        }
                    }
                }
            }

            // Fallback 2: check food database by food name or canonical name
            if (fdb && (newName.isEmpty() || !item.contains(QStringLiteral("nameDe")))) {
                QString searchName = item.contains(QStringLiteral("nameEn")) && !item.value(QStringLiteral("nameEn")).toString().isEmpty()
                    ? item.value(QStringLiteral("nameEn")).toString()
                    : item.value(QStringLiteral("name")).toString();

                QVariantMap info = fdb->findFoodByName(searchName, code);
                if (!info.isEmpty()) {
                    newName = info.value(QStringLiteral("name")).toString();
                    if (!item.contains(QStringLiteral("id")) || item.value(QStringLiteral("id")).toInt() <= 0) {
                        item[QStringLiteral("id")] = info.value(QStringLiteral("id"));
                    }
                    if (!item.contains(QStringLiteral("nameEn"))) item[QStringLiteral("nameEn")] = info.value(QStringLiteral("nameEn"));
                    if (!item.contains(QStringLiteral("nameDe"))) item[QStringLiteral("nameDe")] = info.value(QStringLiteral("nameDe"));
                    if (!item.contains(QStringLiteral("nameFr"))) item[QStringLiteral("nameFr")] = info.value(QStringLiteral("nameFr"));
                    if (!item.contains(QStringLiteral("nameEs"))) item[QStringLiteral("nameEs")] = info.value(QStringLiteral("nameEs"));
                    if (!item.contains(QStringLiteral("nameIt"))) item[QStringLiteral("nameIt")] = info.value(QStringLiteral("nameIt"));
                    if (!item.contains(QStringLiteral("servingSize")) || item.value(QStringLiteral("servingSize")).toDouble() <= 0) {
                        item[QStringLiteral("servingSize")] = info.value(QStringLiteral("servingSize"));
                    }
                    if (!item.contains(QStringLiteral("servingUnit")) || item.value(QStringLiteral("servingUnit")).toString().isEmpty()) {
                        item[QStringLiteral("servingUnit")] = info.value(QStringLiteral("servingUnit"));
                    }
                }
            }

            if (!newName.isEmpty() && item.value(QStringLiteral("name")).toString() != newName) {
                item[QStringLiteral("name")] = newName;
                items[i] = item;
                mealItemsChanged = true;
                anyChanged = true;
            } else if (items[i].toMap() != item) {
                items[i] = item;
                mealItemsChanged = true;
            }
        }

        if (mealItemsChanged) {
            meal[QStringLiteral("items")] = items;
            anyChanged = true;
        }
        m_meals[m] = meal;
    }

    if (anyChanged) {
        emit planChanged();
    }
}
