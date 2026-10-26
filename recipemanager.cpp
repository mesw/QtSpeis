#include "recipemanager.h"
#include "mealplanmanager.h"
#include "fooddatabase.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QUuid>
#include <QDateTime>
#include <QDebug>

RecipeManager::RecipeManager(QObject *parent)
    : QObject(parent)
{
    initCategories();
    loadRecipesFromJson();
    loadCustomTemplatesFromSettings();
    initDefaultWorkouts();
    loadWorkoutTemplatesFromSettings();
}

void RecipeManager::initCategories()
{
    m_categories = {
        QStringLiteral("All"),
        QStringLiteral("Frühstück & Breie"),
        QStringLiteral("Shakes"),
        QStringLiteral("Aufstriche & Salate"),
        QStringLiteral("Suppen & Nudelgerichte"),
        QStringLiteral("Hauptgerichte"),
        QStringLiteral("Süßspeisen"),
        QStringLiteral("Custom")
    };
}

static QString getCategoryIcon(const QString &category)
{
    if (category.contains(QStringLiteral("Frühstück"), Qt::CaseInsensitive)) return QStringLiteral("🥣");
    if (category.contains(QStringLiteral("Shake"), Qt::CaseInsensitive)) return QStringLiteral("🥤");
    if (category.contains(QStringLiteral("Aufstrich"), Qt::CaseInsensitive) || category.contains(QStringLiteral("Salat"), Qt::CaseInsensitive)) return QStringLiteral("🥗");
    if (category.contains(QStringLiteral("Suppe"), Qt::CaseInsensitive) || category.contains(QStringLiteral("Nudel"), Qt::CaseInsensitive)) return QStringLiteral("🍲");
    if (category.contains(QStringLiteral("Hauptgericht"), Qt::CaseInsensitive)) return QStringLiteral("🍽️");
    if (category.contains(QStringLiteral("Süß"), Qt::CaseInsensitive)) return QStringLiteral("🍰");
    return QStringLiteral("🍴");
}

static QString getCategoryColor(const QString &category)
{
    if (category.contains(QStringLiteral("Frühstück"), Qt::CaseInsensitive)) return QStringLiteral("#F59E0B");
    if (category.contains(QStringLiteral("Shake"), Qt::CaseInsensitive)) return QStringLiteral("#06B6D4");
    if (category.contains(QStringLiteral("Aufstrich"), Qt::CaseInsensitive) || category.contains(QStringLiteral("Salat"), Qt::CaseInsensitive)) return QStringLiteral("#10B981");
    if (category.contains(QStringLiteral("Suppe"), Qt::CaseInsensitive) || category.contains(QStringLiteral("Nudel"), Qt::CaseInsensitive)) return QStringLiteral("#8B5CF6");
    if (category.contains(QStringLiteral("Hauptgericht"), Qt::CaseInsensitive)) return QStringLiteral("#3B82F6");
    if (category.contains(QStringLiteral("Süß"), Qt::CaseInsensitive)) return QStringLiteral("#EC4899");
    return QStringLiteral("#64748B");
}

static QString getDefaultMealTime(const QString &category)
{
    if (category.contains(QStringLiteral("Frühstück"), Qt::CaseInsensitive)) return QStringLiteral("08:00");
    if (category.contains(QStringLiteral("Shake"), Qt::CaseInsensitive)) return QStringLiteral("10:30");
    if (category.contains(QStringLiteral("Aufstrich"), Qt::CaseInsensitive) || category.contains(QStringLiteral("Salat"), Qt::CaseInsensitive)) return QStringLiteral("12:30");
    if (category.contains(QStringLiteral("Suppe"), Qt::CaseInsensitive) || category.contains(QStringLiteral("Nudel"), Qt::CaseInsensitive)) return QStringLiteral("13:00");
    if (category.contains(QStringLiteral("Hauptgericht"), Qt::CaseInsensitive)) return QStringLiteral("19:00");
    if (category.contains(QStringLiteral("Süß"), Qt::CaseInsensitive)) return QStringLiteral("16:00");
    return QStringLiteral("12:00");
}

void RecipeManager::loadRecipesFromJson()
{
    const QStringList candidatePaths = {
        QStringLiteral(":/qt/qml/QtSpeis/all_32_recipes_detailed.json"),
        QStringLiteral(":/QtSpeis/all_32_recipes_detailed.json"),
        QStringLiteral(":/all_32_recipes_detailed.json"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/all_32_recipes_detailed.json"),
        QDir::currentPath() + QStringLiteral("/all_32_recipes_detailed.json"),
        QStringLiteral("all_32_recipes_detailed.json")
    };

    QByteArray jsonData;
    for (const auto &path : candidatePaths) {
        if (QFile::exists(path)) {
            QFile file(path);
            if (file.open(QIODevice::ReadOnly)) {
                jsonData = file.readAll();
                qDebug() << "Successfully loaded recipes from:" << path << "(" << jsonData.size() << "bytes )";
                break;
            }
        }
    }

    if (jsonData.isEmpty()) {
        qWarning() << "Failed to find all_32_recipes_detailed.json in candidate locations!";
        return;
    }

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonData, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        qWarning() << "Error parsing recipes JSON:" << err.errorString();
        return;
    }

    m_recipes.clear();
    QJsonArray arr = doc.array();
    for (int i = 0; i < arr.size(); ++i) {
        QJsonObject obj = arr[i].toObject();
        QVariantMap recipeMap = obj.toVariantMap();

        QString cat = recipeMap.value(QStringLiteral("category")).toString();
        recipeMap[QStringLiteral("icon")] = getCategoryIcon(cat);
        recipeMap[QStringLiteral("color")] = getCategoryColor(cat);
        recipeMap[QStringLiteral("defaultTime")] = getDefaultMealTime(cat);

        m_recipes.append(recipeMap);
    }

    qDebug() << "RecipeManager loaded" << m_recipes.size() << "categorized recipes.";
    emit recipesChanged();
}

QVariantMap RecipeManager::getRecipeById(int id) const
{
    for (const auto &v : m_recipes) {
        QVariantMap map = v.toMap();
        if (map.value(QStringLiteral("id")).toInt() == id) {
            return map;
        }
    }
    return QVariantMap();
}

QVariantMap RecipeManager::getRecipeByIndex(int index) const
{
    if (index >= 0 && index < m_recipes.size()) {
        return m_recipes[index].toMap();
    }
    return QVariantMap();
}

bool RecipeManager::loadRecipeIntoPlan(int recipeId, int servings, const QString &time, QObject *mealPlanManagerObj)
{
    MealPlanManager *planMgr = qobject_cast<MealPlanManager*>(mealPlanManagerObj);
    if (!planMgr) {
        qWarning() << "RecipeManager::loadRecipeIntoPlan: Invalid MealPlanManager object!";
        return false;
    }

    QVariantMap recipe = getRecipeById(recipeId);
    if (recipe.isEmpty()) {
        qWarning() << "RecipeManager::loadRecipeIntoPlan: Recipe ID" << recipeId << "not found!";
        return false;
    }

    int baseServings = recipe.value(QStringLiteral("servings"), 1).toInt();
    if (baseServings <= 0) baseServings = 1;
    int targetServings = (servings > 0) ? servings : baseServings;
    double scale = static_cast<double>(targetServings) / static_cast<double>(baseServings);

    QString title = recipe.value(QStringLiteral("title")).toString();
    if (targetServings != 1 && targetServings != baseServings) {
        title += QStringLiteral(" (%1x)").arg(targetServings);
    }

    QString mealTime = time.trimmed().isEmpty() ? recipe.value(QStringLiteral("defaultTime"), QStringLiteral("12:00")).toString() : time.trimmed();
    QString icon = recipe.value(QStringLiteral("icon"), QStringLiteral("🍽️")).toString();
    QString color = recipe.value(QStringLiteral("color"), QStringLiteral("#3B82F6")).toString();

    // 1. Add new Meal container
    int newMealIdx = planMgr->addMeal(title, mealTime, icon, color);
    if (newMealIdx < 0) return false;

    FoodDatabase foodDb;
    foodDb.initDatabase();

    static const QHash<QString, int> s_recipeIngToDbId = {
        { QStringLiteral("haferflocken"), 1 },
        { QStringLiteral("oats"), 1 },
        { QStringLiteral("breakfast cereal"), 1 },
        { QStringLiteral("hirse"), 2 },
        { QStringLiteral("millet"), 2 },
        { QStringLiteral("couscous"), 5 },
        { QStringLiteral("reis"), 7 },
        { QStringLiteral("rice"), 7 },
        { QStringLiteral("basmati rice"), 7 },
        { QStringLiteral("pasta"), 9 },
        { QStringLiteral("macaroni"), 9 },
        { QStringLiteral("teigwaren"), 9 },
        { QStringLiteral("wholewheat bread"), 10 },
        { QStringLiteral("vollkornbrot"), 10 },
        { QStringLiteral("tortilla"), 11 },
        { QStringLiteral("kartoffel"), 15 },
        { QStringLiteral("potato"), 15 },
        { QStringLiteral("erdäpfel"), 15 },
        { QStringLiteral("linse"), 17 },
        { QStringLiteral("lentils"), 17 },
        { QStringLiteral("linsen"), 17 },
        { QStringLiteral("bohne"), 19 },
        { QStringLiteral("beans"), 19 },
        { QStringLiteral("erbse"), 20 },
        { QStringLiteral("peas"), 20 },
        { QStringLiteral("soybean"), 22 },
        { QStringLiteral("sojabohnen"), 22 },
        { QStringLiteral("cottage cheese"), 24 },
        { QStringLiteral("hüttenkäse"), 24 },
        { QStringLiteral("cream cheese"), 25 },
        { QStringLiteral("frischkäse"), 25 },
        { QStringLiteral("ricotta cheese"), 25 },
        { QStringLiteral("joghurt"), 26 },
        { QStringLiteral("yogurt"), 26 },
        { QStringLiteral("naturjogurt"), 26 },
        { QStringLiteral("milch"), 27 },
        { QStringLiteral("milk"), 27 },
        { QStringLiteral("sahne"), 29 },
        { QStringLiteral("cream"), 29 },
        { QStringLiteral("käse"), 30 },
        { QStringLiteral("cheese"), 30 },
        { QStringLiteral("feta cheese"), 31 },
        { QStringLiteral("schafkäse"), 31 },
        { QStringLiteral("parmesan cheese"), 32 },
        { QStringLiteral("parmesan"), 32 },
        { QStringLiteral("truthahn"), 34 },
        { QStringLiteral("turkey"), 34 },
        { QStringLiteral("hühnerfleisch"), 35 },
        { QStringLiteral("chicken"), 35 },
        { QStringLiteral("ham"), 37 },
        { QStringLiteral("schinken"), 37 },
        { QStringLiteral("codfish"), 39 },
        { QStringLiteral("dorsch"), 39 },
        { QStringLiteral("common tuna"), 40 },
        { QStringLiteral("tunfisch"), 40 },
        { QStringLiteral("atlantic herring"), 41 },
        { QStringLiteral("hering"), 41 },
        { QStringLiteral("ei"), 42 },
        { QStringLiteral("egg"), 42 },
        { QStringLiteral("hühnerei"), 42 },
        { QStringLiteral("broccoli"), 43 },
        { QStringLiteral("brokkoli"), 43 },
        { QStringLiteral("karotte"), 45 },
        { QStringLiteral("carrot"), 45 },
        { QStringLiteral("karotten"), 45 },
        { QStringLiteral("spinat"), 46 },
        { QStringLiteral("spinach"), 46 },
        { QStringLiteral("green zucchini"), 48 },
        { QStringLiteral("zucchini"), 48 },
        { QStringLiteral("aubergine"), 49 },
        { QStringLiteral("eggplant"), 49 },
        { QStringLiteral("tomate"), 50 },
        { QStringLiteral("tomato"), 50 },
        { QStringLiteral("paradeiser"), 50 },
        { QStringLiteral("sauce"), 161 },
        { QStringLiteral("paprika"), 51 },
        { QStringLiteral("pepper"), 51 },
        { QStringLiteral("gurke"), 52 },
        { QStringLiteral("cucumber"), 52 },
        { QStringLiteral("gurken"), 52 },
        { QStringLiteral("spargel"), 55 },
        { QStringLiteral("asparagus"), 55 },
        { QStringLiteral("leek"), 59 },
        { QStringLiteral("porree"), 59 },
        { QStringLiteral("zwiebel"), 60 },
        { QStringLiteral("onion"), 60 },
        { QStringLiteral("knoblauch"), 61 },
        { QStringLiteral("garlic"), 61 },
        { QStringLiteral("mais"), 68 },
        { QStringLiteral("corn"), 68 },
        { QStringLiteral("bamboo shoots"), 68 },
        { QStringLiteral("pilz"), 69 },
        { QStringLiteral("mushroom"), 69 },
        { QStringLiteral("pilze"), 69 },
        { QStringLiteral("chicory"), 71 },
        { QStringLiteral("apfel"), 73 },
        { QStringLiteral("apple"), 73 },
        { QStringLiteral("apple sauce"), 73 },
        { QStringLiteral("birne"), 74 },
        { QStringLiteral("pear"), 74 },
        { QStringLiteral("banane"), 75 },
        { QStringLiteral("banana"), 75 },
        { QStringLiteral("pfirsich"), 77 },
        { QStringLiteral("peach"), 77 },
        { QStringLiteral("himbeere"), 81 },
        { QStringLiteral("raspberry"), 81 },
        { QStringLiteral("raisin"), 84 },
        { QStringLiteral("dattel"), 84 },
        { QStringLiteral("orange"), 85 },
        { QStringLiteral("haselnuss"), 89 },
        { QStringLiteral("hazelnut"), 89 },
        { QStringLiteral("olive"), 91 },
        { QStringLiteral("canola oil"), 92 },
        { QStringLiteral("rapsöl"), 92 },
        { QStringLiteral("sunflower"), 108 },
        { QStringLiteral("butter"), 93 },
        { QStringLiteral("margarine"), 93 },
        { QStringLiteral("petersilie"), 94 },
        { QStringLiteral("parsley"), 94 },
        { QStringLiteral("chive"), 95 },
        { QStringLiteral("schnittlauch"), 95 },
        { QStringLiteral("dill"), 96 },
        { QStringLiteral("dille"), 96 },
        { QStringLiteral("basilikum"), 97 },
        { QStringLiteral("basil"), 97 },
        { QStringLiteral("rosmarin"), 98 },
        { QStringLiteral("rosemary"), 98 },
        { QStringLiteral("thymian"), 98 },
        { QStringLiteral("curry leaf"), 98 },
        { QStringLiteral("zimt"), 99 },
        { QStringLiteral("cinnamon"), 99 },
        { QStringLiteral("senf"), 101 },
        { QStringLiteral("mustard"), 101 },
        { QStringLiteral("honig"), 102 },
        { QStringLiteral("honey"), 102 },
        { QStringLiteral("cocoa powder"), 103 },
        { QStringLiteral("kakaopulver"), 103 },
        { QStringLiteral("ingwer"), 122 },
        { QStringLiteral("ginger"), 122 },
        { QStringLiteral("chili"), 123 },
        { QStringLiteral("zitrone"), 126 },
        { QStringLiteral("lemon"), 126 },
        { QStringLiteral("mehl"), 158 },
        { QStringLiteral("flour"), 158 },
        { QStringLiteral("weizenmehl"), 158 },
        { QStringLiteral("essig"), 162 },
        { QStringLiteral("vinegar"), 162 },
        { QStringLiteral("salz"), 163 },
        { QStringLiteral("salt"), 163 },
        { QStringLiteral("speisesalz"), 163 },
        { QStringLiteral("soybean sauce"), 163 },
        { QStringLiteral("zucker"), 165 },
        { QStringLiteral("sugar"), 165 },
        { QStringLiteral("tee"), 172 },
        { QStringLiteral("tea"), 172 }
    };

    // 2. Add each individual ingredient as an editable meal item
    QVariantList ingredients = recipe.value(QStringLiteral("ingredients")).toList();
    for (const auto &ingVar : ingredients) {
        QVariantMap ing = ingVar.toMap();
        double baseGrams = ing.value(QStringLiteral("weight_g"), 100.0).toDouble();
        if (baseGrams <= 0.0) baseGrams = 100.0;
        double targetGrams = baseGrams * scale;

        double baseKcal = ing.value(QStringLiteral("calories"), 0.0).toDouble();
        double baseProt = ing.value(QStringLiteral("protein"), 0.0).toDouble();
        double baseFat = ing.value(QStringLiteral("fat"), 0.0).toDouble();
        double baseCarbs = ing.value(QStringLiteral("carbs"), 0.0).toDouble();
        double baseFiber = ing.value(QStringLiteral("fiber"), 0.0).toDouble();

        // Calculate base nutrient density per 100g
        double cal100 = (baseKcal / baseGrams) * 100.0;
        double prot100 = (baseProt / baseGrams) * 100.0;
        double fat100 = (baseFat / baseGrams) * 100.0;
        double carbs100 = (baseCarbs / baseGrams) * 100.0;
        double fib100 = (baseFiber / baseGrams) * 100.0;

        QString nameDe = ing.value(QStringLiteral("name_de")).toString().trimmed();
        QString nameEn = ing.value(QStringLiteral("name_en")).toString().trimmed();
        QString rawName = ing.value(QStringLiteral("name")).toString().trimmed();

        QVariantMap food;
        bool isWater = (nameDe.compare(QStringLiteral("Wasser"), Qt::CaseInsensitive) == 0 ||
                        nameEn.compare(QStringLiteral("Water"), Qt::CaseInsensitive) == 0 ||
                        rawName.compare(QStringLiteral("Wasser"), Qt::CaseInsensitive) == 0);

        if (isWater) {
            food[QStringLiteral("id")] = 0;
            food[QStringLiteral("name")] = rawName.isEmpty() ? QStringLiteral("Wasser") : rawName;
            food[QStringLiteral("nameDe")] = QStringLiteral("Wasser");
            food[QStringLiteral("nameEn")] = QStringLiteral("Water");
            food[QStringLiteral("category")] = QStringLiteral("Getränke");
            food[QStringLiteral("icon")] = QStringLiteral("💧");
            food[QStringLiteral("servingSize")] = 200.0;
            food[QStringLiteral("servingUnit")] = QStringLiteral("ml");
            food[QStringLiteral("calcium")] = 3.0;
            food[QStringLiteral("magnesium")] = 1.0;
        } else {
            int dbId = s_recipeIngToDbId.value(nameDe.toLower(), 0);
            if (dbId == 0) dbId = s_recipeIngToDbId.value(nameEn.toLower(), 0);
            if (dbId == 0) dbId = s_recipeIngToDbId.value(rawName.toLower(), 0);

            if (dbId > 0) {
                food = foodDb.getFoodById(dbId);
            }
            if (food.isEmpty() && !nameDe.isEmpty()) {
                food = foodDb.findFoodByName(nameDe);
            }
            if (food.isEmpty() && !nameEn.isEmpty()) {
                food = foodDb.findFoodByName(nameEn);
            }
        }

        if (food.isEmpty()) {
            food[QStringLiteral("id")] = 0;
            food[QStringLiteral("icon")] = QStringLiteral("🥗");
        }

        if (!rawName.isEmpty()) food[QStringLiteral("name")] = rawName;
        if (!nameDe.isEmpty()) food[QStringLiteral("nameDe")] = nameDe;
        if (!nameEn.isEmpty()) food[QStringLiteral("nameEn")] = nameEn;
        if (!food.contains(QStringLiteral("category")) || food.value(QStringLiteral("category")).toString().isEmpty()) {
            food[QStringLiteral("category")] = ing.value(QStringLiteral("category"), QStringLiteral("Recipe")).toString();
        }

        // Preserve recipe's exact macro density while inheriting full micronutrients from speis.db
        food[QStringLiteral("caloriesPer100g")] = cal100;
        food[QStringLiteral("proteinPer100g")] = prot100;
        food[QStringLiteral("fatPer100g")] = fat100;
        food[QStringLiteral("carbsPer100g")] = carbs100;
        food[QStringLiteral("fiberPer100g")] = fib100;
        food.remove(QStringLiteral("amount"));

        planMgr->addItemToMeal(newMealIdx, food, targetGrams);
    }

    return true;
}

void RecipeManager::loadCustomTemplatesFromSettings()
{
    m_customMealTemplates.clear();
    QSettings settings;
    QString jsonStr = settings.value(QStringLiteral("speis_custom_meal_templates_v1")).toString();
    if (!jsonStr.trimmed().isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
        if (doc.isArray()) {
            QJsonArray arr = doc.array();
            for (const auto &val : arr) {
                m_customMealTemplates.append(val.toObject().toVariantMap());
            }
        }
    }
    emit customMealTemplatesChanged();
}

void RecipeManager::saveCustomTemplatesToSettings()
{
    QJsonArray arr;
    for (const auto &v : m_customMealTemplates) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    QJsonDocument doc(arr);
    QSettings settings;
    settings.setValue(QStringLiteral("speis_custom_meal_templates_v1"), QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
    emit customMealTemplatesChanged();
}

bool RecipeManager::saveMealAsTemplate(int mealIndex, const QString &templateName, QObject *mealPlanManagerObj)
{
    MealPlanManager *planMgr = qobject_cast<MealPlanManager*>(mealPlanManagerObj);
    if (!planMgr) return false;

    QVariantList meals = planMgr->meals();
    if (mealIndex < 0 || mealIndex >= meals.size()) return false;

    QVariantMap sourceMeal = meals[mealIndex].toMap();
    if (sourceMeal.value(QStringLiteral("isWorkout")).toBool()) return false;

    QString name = templateName.trimmed();
    if (name.isEmpty()) {
        name = sourceMeal.value(QStringLiteral("title"), QStringLiteral("Custom Meal")).toString();
    }

    QVariantMap tpl;
    tpl[QStringLiteral("id")] = QStringLiteral("tpl_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    tpl[QStringLiteral("title")] = name;
    tpl[QStringLiteral("icon")] = sourceMeal.value(QStringLiteral("icon"), QStringLiteral("🍽️")).toString();
    tpl[QStringLiteral("color")] = sourceMeal.value(QStringLiteral("color"), QStringLiteral("#3B82F6")).toString();
    tpl[QStringLiteral("defaultTime")] = sourceMeal.value(QStringLiteral("time"), QStringLiteral("12:00")).toString();
    tpl[QStringLiteral("items")] = sourceMeal.value(QStringLiteral("items")).toList();
    tpl[QStringLiteral("calories")] = sourceMeal.value(QStringLiteral("calories"), 0.0).toDouble();
    tpl[QStringLiteral("carbs")] = sourceMeal.value(QStringLiteral("carbs"), 0.0).toDouble();
    tpl[QStringLiteral("protein")] = sourceMeal.value(QStringLiteral("protein"), 0.0).toDouble();
    tpl[QStringLiteral("fat")] = sourceMeal.value(QStringLiteral("fat"), 0.0).toDouble();
    tpl[QStringLiteral("fiber")] = sourceMeal.value(QStringLiteral("fiber"), 0.0).toDouble();
    tpl[QStringLiteral("createdAt")] = QDateTime::currentDateTime().toString(Qt::ISODate);

    m_customMealTemplates.prepend(tpl);
    saveCustomTemplatesToSettings();
    return true;
}

bool RecipeManager::deleteCustomMealTemplate(int templateIndex)
{
    if (templateIndex < 0 || templateIndex >= m_customMealTemplates.size()) return false;
    m_customMealTemplates.removeAt(templateIndex);
    saveCustomTemplatesToSettings();
    return true;
}

bool RecipeManager::loadTemplateIntoPlan(int templateIndex, const QString &time, QObject *mealPlanManagerObj)
{
    MealPlanManager *planMgr = qobject_cast<MealPlanManager*>(mealPlanManagerObj);
    if (!planMgr) return false;

    if (templateIndex < 0 || templateIndex >= m_customMealTemplates.size()) return false;
    QVariantMap tpl = m_customMealTemplates[templateIndex].toMap();

    QString mealTime = time.trimmed().isEmpty() ? tpl.value(QStringLiteral("defaultTime"), QStringLiteral("12:00")).toString() : time.trimmed();
    QString title = tpl.value(QStringLiteral("title"), QStringLiteral("Custom Meal")).toString();
    QString icon = tpl.value(QStringLiteral("icon"), QStringLiteral("🍽️")).toString();
    QString color = tpl.value(QStringLiteral("color"), QStringLiteral("#3B82F6")).toString();

    int newMealIdx = planMgr->addMeal(title, mealTime, icon, color);
    if (newMealIdx < 0) return false;

    QVariantList items = tpl.value(QStringLiteral("items")).toList();
    for (const auto &itemVar : items) {
        QVariantMap item = itemVar.toMap();
        double amount = item.value(QStringLiteral("amount"), 100.0).toDouble();
        planMgr->addItemToMeal(newMealIdx, item, amount);
    }

    return true;
}

void RecipeManager::initDefaultWorkouts()
{
    struct DefaultWorkout {
        const char *id;
        const char *title;
        const char *type;
        const char *icon;
        const char *color;
        int duration;
        double calories;
        double carbs;
        double protein;
        double fat;
        const char *desc;
    };

    const DefaultWorkout defaults[] = {
        { "run_mod", "Jogging / Running (Steady)", "running", "🏃", "#EF4444", 45, 450.0, 65.0, 10.0, 15.0, "Moderate pace aerobic running, balanced glycogen and lipid burn." },
        { "run_hiit", "Sprint & Interval Training (HIIT)", "hiit", "⚡", "#F97316", 30, 380.0, 70.0, 9.0, 7.0, "High anaerobic demand; predominantly rapidly depleted carbohydrates." },
        { "bike_end", "Road Cycling (Endurance)", "cycling", "🚴", "#3B82F6", 60, 520.0, 85.0, 9.0, 16.0, "Extended steady-state cycling with significant total energy expenditure." },
        { "swim_laps", "Lap Swimming (Freestyle)", "swimming", "🏊", "#06B6D4", 45, 480.0, 70.0, 14.0, 16.0, "Full-body continuous resistance in water; high caloric consumption." },
        { "strength_hyp", "Hypertrophy Strength Training", "strength", "🏋️", "#8B5CF6", 60, 380.0, 45.0, 25.0, 10.0, "Moderate-heavy volume lifting; stimulates high muscle protein turnover." },
        { "powerlifting", "Heavy Powerlifting & Peaking", "strength", "💥", "#6366F1", 75, 350.0, 40.0, 28.0, 9.0, "Max effort sets with long rest periods; phosphagen & EAA demanding." },
        { "crossfit", "CrossFit / MetCon WOD", "hiit", "🔥", "#EA580C", 45, 480.0, 75.0, 14.0, 14.0, "High metabolic conditioning circuit mixing gymnastics and barbell work." },
        { "rowing", "Rowing Machine (Ergometer)", "cardio", "🚣", "#0D9488", 30, 320.0, 50.0, 10.0, 9.0, "Cardio and posterior chain endurance workout." },
        { "bouldering", "Bouldering & Rock Climbing", "strength", "🧗", "#78716C", 60, 400.0, 50.0, 20.0, 12.0, "Intermittent isometric gripping and athletic core power." },
        { "brisk_walk", "Incline Walk / Rucking", "cardio", "🚶", "#84CC16", 45, 240.0, 30.0, 3.0, 12.0, "Low intensity steady state (LISS); high relative fat oxidation." },
        { "yoga", "Vinyasa Yoga & Core Flow", "mobility", "🧘", "#10B981", 45, 180.0, 22.0, 5.0, 8.0, "Mindful movement, flexibility, balance, and deep postural stabilization." },
        { "stretching", "Mobility & Foam Rolling Recovery", "mobility", "🤸", "#EC4899", 30, 90.0, 10.0, 2.0, 4.0, "Low stress myofascial release, parasympathetic recovery stimulation." }
    };

    m_workoutTemplates.clear();
    for (const auto &w : defaults) {
        QVariantMap map;
        map[QStringLiteral("id")] = QString::fromUtf8(w.id);
        map[QStringLiteral("title")] = QString::fromUtf8(w.title);
        map[QStringLiteral("type")] = QString::fromUtf8(w.type);
        map[QStringLiteral("icon")] = QString::fromUtf8(w.icon);
        map[QStringLiteral("color")] = QString::fromUtf8(w.color);
        map[QStringLiteral("duration")] = w.duration;
        map[QStringLiteral("calories")] = w.calories;
        map[QStringLiteral("carbs")] = w.carbs;
        map[QStringLiteral("protein")] = w.protein;
        map[QStringLiteral("fat")] = w.fat;
        map[QStringLiteral("description")] = QString::fromUtf8(w.desc);
        map[QStringLiteral("isDefault")] = true;
        m_workoutTemplates.append(map);
    }
}

void RecipeManager::loadWorkoutTemplatesFromSettings()
{
    QSettings settings;
    QString jsonStr = settings.value(QStringLiteral("speis_custom_workout_templates_v1")).toString();
    if (!jsonStr.trimmed().isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
        if (doc.isArray()) {
            QJsonArray arr = doc.array();
            for (const auto &val : arr) {
                QVariantMap map = val.toObject().toVariantMap();
                map[QStringLiteral("isDefault")] = false;
                m_workoutTemplates.append(map);
            }
        }
    }
    emit workoutTemplatesChanged();
}

void RecipeManager::saveWorkoutTemplatesToSettings()
{
    QJsonArray customArr;
    for (const auto &v : m_workoutTemplates) {
        QVariantMap map = v.toMap();
        if (!map.value(QStringLiteral("isDefault")).toBool()) {
            customArr.append(QJsonObject::fromVariantMap(map));
        }
    }
    QJsonDocument doc(customArr);
    QSettings settings;
    settings.setValue(QStringLiteral("speis_custom_workout_templates_v1"), QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
    emit workoutTemplatesChanged();
}

bool RecipeManager::addWorkoutFromPreset(int presetIndex, int durationMinutes, const QString &time, QObject *mealPlanManagerObj)
{
    MealPlanManager *planMgr = qobject_cast<MealPlanManager*>(mealPlanManagerObj);
    if (!planMgr) return false;

    if (presetIndex < 0 || presetIndex >= m_workoutTemplates.size()) return false;
    QVariantMap preset = m_workoutTemplates[presetIndex].toMap();

    int baseDur = preset.value(QStringLiteral("duration"), 45).toInt();
    if (baseDur <= 0) baseDur = 45;
    int targetDur = (durationMinutes > 0) ? durationMinutes : baseDur;
    double scale = static_cast<double>(targetDur) / static_cast<double>(baseDur);

    double cals = preset.value(QStringLiteral("calories"), 300.0).toDouble() * scale;
    double carbs = preset.value(QStringLiteral("carbs"), 50.0).toDouble() * scale;
    double prot = preset.value(QStringLiteral("protein"), 10.0).toDouble() * scale;
    double fat = preset.value(QStringLiteral("fat"), 10.0).toDouble() * scale;

    QString type = preset.value(QStringLiteral("type"), QStringLiteral("cardio")).toString();
    QString workoutTime = time.trimmed().isEmpty() ? QStringLiteral("17:00") : time.trimmed();

    planMgr->addWorkout(type, workoutTime, targetDur, cals, carbs, prot, fat);
    return true;
}

bool RecipeManager::saveWorkoutAsTemplate(const QString &title, const QString &type, const QString &time, int durationMinutes,
                                          double calories, double carbs, double protein, double fat)
{
    Q_UNUSED(time);
    QVariantMap map;
    map[QStringLiteral("id")] = QStringLiteral("wkt_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    map[QStringLiteral("title")] = title.trimmed().isEmpty() ? QStringLiteral("Custom Workout") : title.trimmed();
    map[QStringLiteral("type")] = type;
    map[QStringLiteral("icon")] = QStringLiteral("⚡");
    map[QStringLiteral("color")] = QStringLiteral("#F97316");
    map[QStringLiteral("duration")] = durationMinutes;
    map[QStringLiteral("calories")] = calories;
    map[QStringLiteral("carbs")] = carbs;
    map[QStringLiteral("protein")] = protein;
    map[QStringLiteral("fat")] = fat;
    map[QStringLiteral("description")] = QStringLiteral("Custom user tailored workout.");
    map[QStringLiteral("isDefault")] = false;

    m_workoutTemplates.append(map);
    saveWorkoutTemplatesToSettings();
    return true;
}

bool RecipeManager::deleteWorkoutTemplate(int index)
{
    if (index < 0 || index >= m_workoutTemplates.size()) return false;
    if (m_workoutTemplates[index].toMap().value(QStringLiteral("isDefault")).toBool()) {
        return false; // Cannot delete standard default workouts
    }
    m_workoutTemplates.removeAt(index);
    saveWorkoutTemplatesToSettings();
    return true;
}
