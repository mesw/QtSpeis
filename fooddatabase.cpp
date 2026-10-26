#include "fooddatabase.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QCoreApplication>
#include <QDebug>
#include <QUuid>

static inline QString nameColForLang(const QString &lang) {
    if (lang == QStringLiteral("de")) return QStringLiteral("name_de");
    if (lang == QStringLiteral("fr")) return QStringLiteral("name_fr");
    if (lang == QStringLiteral("es")) return QStringLiteral("name_es");
    if (lang == QStringLiteral("it")) return QStringLiteral("name_it");
    return QStringLiteral("name_en");
}

static inline QString catColForLang(const QString &lang) {
    if (lang == QStringLiteral("de")) return QStringLiteral("category_de");
    if (lang == QStringLiteral("fr")) return QStringLiteral("category_fr");
    if (lang == QStringLiteral("es")) return QStringLiteral("category_es");
    if (lang == QStringLiteral("it")) return QStringLiteral("category_it");
    return QStringLiteral("category");
}

static inline QString resolveDisplayName(const QSqlQuery &q, const QString &lang) {
    QString col = nameColForLang(lang);
    if (q.record().indexOf(col) != -1) {
        QString val = q.value(col).toString().trimmed();
        if (!val.isEmpty()) return val;
    }
    if (q.record().indexOf(QStringLiteral("name_en")) != -1) {
        QString en = q.value(QStringLiteral("name_en")).toString().trimmed();
        if (!en.isEmpty()) return en;
    }
    return q.value(QStringLiteral("name")).toString();
}

QString FoodDatabase::localizeCategory(const QString &rawCat, const QString &lang)
{
    bool isEn = (lang.trimmed().toLower() == QStringLiteral("en"));
    QString c = rawCat.trimmed();
    if (c.compare(QStringLiteral("Getreide"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Grains & Cereals") : QStringLiteral("Getreide");
    if (c.compare(QStringLiteral("Gemüse"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Vegetables") : QStringLiteral("Gemüse");
    if (c.compare(QStringLiteral("Obst"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Fruits") : QStringLiteral("Obst");
    if (c.compare(QStringLiteral("Milchprodukte"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Dairy") : QStringLiteral("Milchprodukte");
    if (c.compare(QStringLiteral("Kräuter"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Herbs & Spices") : QStringLiteral("Kräuter");
    if (c.compare(QStringLiteral("Nüsse"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Nuts & Seeds") : QStringLiteral("Nüsse & Samen");
    if (c.compare(QStringLiteral("Fleisch"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Meat & Poultry") : QStringLiteral("Fleisch");
    if (c.compare(QStringLiteral("Hülsenfrüchte"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Legumes") : QStringLiteral("Hülsenfrüchte");
    if (c.compare(QStringLiteral("Fisch"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Fish & Seafood") : QStringLiteral("Fisch");
    if (c.compare(QStringLiteral("Süßungsmittel"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Sweeteners") : QStringLiteral("Süßungsmittel");
    if (c.compare(QStringLiteral("Öle & Fette"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Oils & Fats") : QStringLiteral("Öle & Fette");
    if (c.compare(QStringLiteral("Salat"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Salads & Greens") : QStringLiteral("Salat");
    if (c.compare(QStringLiteral("Getränke"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Beverages") : QStringLiteral("Getränke");
    if (c.compare(QStringLiteral("Eier"), Qt::CaseInsensitive) == 0) return isEn ? QStringLiteral("Eggs") : QStringLiteral("Eier");
    return c;
}

QString FoodDatabase::mapToDbCategory(const QString &filter)
{
    QString f = filter.trimmed().toLower();
    if (f.isEmpty() || f == QStringLiteral("all") || f == QStringLiteral("alle")) return QString();
    if (f.contains(QStringLiteral("grain")) || f.contains(QStringLiteral("getreide"))) return QStringLiteral("Getreide");
    if (f.contains(QStringLiteral("veg")) || f.contains(QStringLiteral("gemüse")) || f.contains(QStringLiteral("gemuse"))) return QStringLiteral("Gemüse");
    if (f.contains(QStringLiteral("fruit")) || f.contains(QStringLiteral("obst"))) return QStringLiteral("Obst");
    if (f.contains(QStringLiteral("dair")) || f.contains(QStringLiteral("milch"))) return QStringLiteral("Milchprodukte");
    if (f.contains(QStringLiteral("herb")) || f.contains(QStringLiteral("kräuter")) || f.contains(QStringLiteral("kraut"))) return QStringLiteral("Kräuter");
    if (f.contains(QStringLiteral("nut")) || f.contains(QStringLiteral("nuss")) || f.contains(QStringLiteral("nüsse"))) return QStringLiteral("Nüsse");
    if (f.contains(QStringLiteral("meat")) || f.contains(QStringLiteral("fleisch")) || f.contains(QStringLiteral("poultry"))) return QStringLiteral("Fleisch");
    if (f.contains(QStringLiteral("legume")) || f.contains(QStringLiteral("hülsen")) || f.contains(QStringLiteral("bean"))) return QStringLiteral("Hülsenfrüchte");
    if (f.contains(QStringLiteral("fish")) || f.contains(QStringLiteral("fisch")) || f.contains(QStringLiteral("seafood"))) return QStringLiteral("Fisch");
    if (f.contains(QStringLiteral("sweet")) || f.contains(QStringLiteral("süß")) || f.contains(QStringLiteral("suss"))) return QStringLiteral("Süßungsmittel");
    if (f.contains(QStringLiteral("oil")) || f.contains(QStringLiteral("öl")) || f.contains(QStringLiteral("fat")) || f.contains(QStringLiteral("fett"))) return QStringLiteral("Öle & Fette");
    if (f.contains(QStringLiteral("salad")) || f.contains(QStringLiteral("salat")) || f.contains(QStringLiteral("green"))) return QStringLiteral("Salat");
    if (f.contains(QStringLiteral("bev")) || f.contains(QStringLiteral("getränk")) || f.contains(QStringLiteral("drink"))) return QStringLiteral("Getränke");
    if (f.contains(QStringLiteral("egg")) || f.contains(QStringLiteral("ei"))) return QStringLiteral("Eier");
    return filter;
}

static inline QString resolveDisplayCat(const QSqlQuery &q, const QString &lang) {
    QString raw = q.value(QStringLiteral("category")).toString();
    return FoodDatabase::localizeCategory(raw, lang);
}

static QVariantMap recordToFoodMap(const QSqlQuery &q, const QString &activeLang, const QString &lowerQuery = QString())
{
    QVariantMap item;
    int rank = 1;
    if (q.record().indexOf(QStringLiteral("rank")) != -1) {
        rank = q.value(QStringLiteral("rank")).toInt();
    }

    QString nameEn = q.record().indexOf(QStringLiteral("name_en")) != -1 ? q.value(QStringLiteral("name_en")).toString() : q.value(QStringLiteral("name")).toString();
    QString nameDe = q.record().indexOf(QStringLiteral("name_de")) != -1 ? q.value(QStringLiteral("name_de")).toString() : QString();
    QString nameFr = q.record().indexOf(QStringLiteral("name_fr")) != -1 ? q.value(QStringLiteral("name_fr")).toString() : QString();
    QString nameEs = q.record().indexOf(QStringLiteral("name_es")) != -1 ? q.value(QStringLiteral("name_es")).toString() : QString();
    QString nameIt = q.record().indexOf(QStringLiteral("name_it")) != -1 ? q.value(QStringLiteral("name_it")).toString() : QString();

    QString displayName = resolveDisplayName(q, activeLang);
    QString displayCat = resolveDisplayCat(q, activeLang);

    item[QStringLiteral("id")] = q.value(QStringLiteral("id")).toInt();
    item[QStringLiteral("name")] = displayName;
    item[QStringLiteral("category")] = displayCat;
    item[QStringLiteral("nameEn")] = nameEn;
    item[QStringLiteral("nameDe")] = nameDe;
    item[QStringLiteral("nameFr")] = nameFr;
    item[QStringLiteral("nameEs")] = nameEs;
    item[QStringLiteral("nameIt")] = nameIt;
    QString rawCat = q.record().indexOf(QStringLiteral("category")) != -1 ? q.value(QStringLiteral("category")).toString() : QString();
    item[QStringLiteral("categoryDe")] = FoodDatabase::localizeCategory(rawCat, QStringLiteral("de"));
    item[QStringLiteral("categoryEn")] = FoodDatabase::localizeCategory(rawCat, QStringLiteral("en"));
    item[QStringLiteral("mealRole")] = q.record().indexOf(QStringLiteral("meal_role")) != -1 ? q.value(QStringLiteral("meal_role")).toString() : QStringLiteral("snack");
    item[QStringLiteral("giClass")] = q.record().indexOf(QStringLiteral("gi_class")) != -1 ? q.value(QStringLiteral("gi_class")).toString() : QStringLiteral("low");
    item[QStringLiteral("gastricEmptyingHours")] = q.record().indexOf(QStringLiteral("gastric_emptying_hours")) != -1 ? q.value(QStringLiteral("gastric_emptying_hours")).toDouble() : 2.0;

    // Macros
    item[QStringLiteral("calories")] = q.record().indexOf(QStringLiteral("calories")) != -1 ? q.value(QStringLiteral("calories")).toDouble() : 0.0;
    item[QStringLiteral("carbs")] = q.record().indexOf(QStringLiteral("carbs")) != -1 ? q.value(QStringLiteral("carbs")).toDouble() : 0.0;
    item[QStringLiteral("protein")] = q.record().indexOf(QStringLiteral("protein")) != -1 ? q.value(QStringLiteral("protein")).toDouble() : 0.0;
    item[QStringLiteral("fat")] = q.record().indexOf(QStringLiteral("fat")) != -1 ? q.value(QStringLiteral("fat")).toDouble() : 0.0;
    item[QStringLiteral("fiber")] = q.record().indexOf(QStringLiteral("fiber")) != -1 ? q.value(QStringLiteral("fiber")).toDouble() : 0.0;

    // Sub-lipids
    item[QStringLiteral("satFat")] = q.record().indexOf(QStringLiteral("sat_fat")) != -1 ? q.value(QStringLiteral("sat_fat")).toDouble() : 0.0;
    item[QStringLiteral("mufa")] = q.record().indexOf(QStringLiteral("mufa")) != -1 ? q.value(QStringLiteral("mufa")).toDouble() : 0.0;
    item[QStringLiteral("pufa")] = q.record().indexOf(QStringLiteral("pufa")) != -1 ? q.value(QStringLiteral("pufa")).toDouble() : 0.0;
    item[QStringLiteral("omega3")] = q.record().indexOf(QStringLiteral("omega_3")) != -1 ? q.value(QStringLiteral("omega_3")).toDouble() : 0.0;
    item[QStringLiteral("omega6")] = q.record().indexOf(QStringLiteral("omega_6")) != -1 ? q.value(QStringLiteral("omega_6")).toDouble() : 0.0;

    // Minerals
    item[QStringLiteral("calcium")] = q.record().indexOf(QStringLiteral("calcium")) != -1 ? q.value(QStringLiteral("calcium")).toDouble() : 0.0;
    item[QStringLiteral("iron")] = q.record().indexOf(QStringLiteral("iron")) != -1 ? q.value(QStringLiteral("iron")).toDouble() : 0.0;
    item[QStringLiteral("zinc")] = q.record().indexOf(QStringLiteral("zinc")) != -1 ? q.value(QStringLiteral("zinc")).toDouble() : 0.0;
    item[QStringLiteral("copper")] = q.record().indexOf(QStringLiteral("copper")) != -1 ? q.value(QStringLiteral("copper")).toDouble() : 0.0;
    item[QStringLiteral("magnesium")] = q.record().indexOf(QStringLiteral("magnesium")) != -1 ? q.value(QStringLiteral("magnesium")).toDouble() : 0.0;
    item[QStringLiteral("potassium")] = q.record().indexOf(QStringLiteral("potassium")) != -1 ? q.value(QStringLiteral("potassium")).toDouble() : 0.0;
    item[QStringLiteral("sodium")] = q.record().indexOf(QStringLiteral("sodium")) != -1 ? q.value(QStringLiteral("sodium")).toDouble() : 0.0;

    // Vitamins & Amino Acids
    item[QStringLiteral("vitaminA")] = q.record().indexOf(QStringLiteral("vitamin_a")) != -1 ? q.value(QStringLiteral("vitamin_a")).toDouble() : 0.0;
    item[QStringLiteral("vitaminC")] = q.record().indexOf(QStringLiteral("vitamin_c")) != -1 ? q.value(QStringLiteral("vitamin_c")).toDouble() : 0.0;
    item[QStringLiteral("vitaminD")] = q.record().indexOf(QStringLiteral("vitamin_d")) != -1 ? q.value(QStringLiteral("vitamin_d")).toDouble() : 0.0;
    item[QStringLiteral("vitaminE")] = q.record().indexOf(QStringLiteral("vitamin_e")) != -1 ? q.value(QStringLiteral("vitamin_e")).toDouble() : 0.0;
    item[QStringLiteral("vitaminK")] = q.record().indexOf(QStringLiteral("vitamin_k")) != -1 ? q.value(QStringLiteral("vitamin_k")).toDouble() : 0.0;
    item[QStringLiteral("thiamine")] = q.record().indexOf(QStringLiteral("thiamine")) != -1 ? q.value(QStringLiteral("thiamine")).toDouble() : 0.0;
    item[QStringLiteral("leucine")] = q.record().indexOf(QStringLiteral("leucine")) != -1 ? q.value(QStringLiteral("leucine")).toDouble() : 0.0;
    item[QStringLiteral("tryptophan")] = q.record().indexOf(QStringLiteral("tryptophan")) != -1 ? q.value(QStringLiteral("tryptophan")).toDouble() : 0.0;

    // Biochemical markers
    item[QStringLiteral("ironType")] = q.record().indexOf(QStringLiteral("iron_type")) != -1 ? q.value(QStringLiteral("iron_type")).toString() : QStringLiteral("none");
    item[QStringLiteral("isDairyCalcium")] = q.record().indexOf(QStringLiteral("is_dairy_calcium")) != -1 ? q.value(QStringLiteral("is_dairy_calcium")).toInt() : 0;
    item[QStringLiteral("polyphenolLevel")] = q.record().indexOf(QStringLiteral("polyphenol_level")) != -1 ? q.value(QStringLiteral("polyphenol_level")).toInt() : 0;
    item[QStringLiteral("containsCaffeine")] = q.record().indexOf(QStringLiteral("contains_caffeine")) != -1 ? q.value(QStringLiteral("contains_caffeine")).toInt() : 0;
    item[QStringLiteral("phytateMg")] = q.record().indexOf(QStringLiteral("phytate_mg")) != -1 ? q.value(QStringLiteral("phytate_mg")).toDouble() : 0.0;
    item[QStringLiteral("oxalateMg")] = q.record().indexOf(QStringLiteral("oxalate_mg")) != -1 ? q.value(QStringLiteral("oxalate_mg")).toDouble() : 0.0;
    item[QStringLiteral("isViscousFiber")] = q.record().indexOf(QStringLiteral("is_viscous_fiber")) != -1 ? q.value(QStringLiteral("is_viscous_fiber")).toInt() : 0;
    item[QStringLiteral("isNightshade")] = q.record().indexOf(QStringLiteral("is_nightshade")) != -1 ? q.value(QStringLiteral("is_nightshade")).toInt() : 0;
    item[QStringLiteral("isSeed")] = q.record().indexOf(QStringLiteral("is_seed")) != -1 ? q.value(QStringLiteral("is_seed")).toInt() : 0;
    item[QStringLiteral("fodmapLevel")] = q.record().indexOf(QStringLiteral("fodmap_level")) != -1 ? q.value(QStringLiteral("fodmap_level")).toString() : QStringLiteral("low");
    item[QStringLiteral("isFermented")] = q.record().indexOf(QStringLiteral("is_fermented")) != -1 ? q.value(QStringLiteral("is_fermented")).toInt() : 0;
    item[QStringLiteral("hasPhosvitin")] = q.record().indexOf(QStringLiteral("has_phosvitin")) != -1 ? q.value(QStringLiteral("has_phosvitin")).toInt() : 0;

    // Serving & icon
    item[QStringLiteral("servingSize")] = q.record().indexOf(QStringLiteral("serving_size")) != -1 ? q.value(QStringLiteral("serving_size")).toDouble() : 100.0;
    item[QStringLiteral("servingUnit")] = q.record().indexOf(QStringLiteral("serving_unit")) != -1 ? q.value(QStringLiteral("serving_unit")).toString() : QStringLiteral("g");
    item[QStringLiteral("icon")] = q.record().indexOf(QStringLiteral("icon")) != -1 ? q.value(QStringLiteral("icon")).toString() : QStringLiteral("🍽️");
    item[QStringLiteral("barcode")] = q.record().indexOf(QStringLiteral("barcode")) != -1 ? q.value(QStringLiteral("barcode")).toString() : QString();

    if (rank >= 4 && !lowerQuery.isEmpty()) {
        item[QStringLiteral("matchedInOtherLanguage")] = true;
        if (nameEn.toLower().contains(lowerQuery)) {
            item[QStringLiteral("matchedLanguage")] = QStringLiteral("EN");
            item[QStringLiteral("matchedText")] = nameEn;
        } else if (nameDe.toLower().contains(lowerQuery)) {
            item[QStringLiteral("matchedLanguage")] = QStringLiteral("DE");
            item[QStringLiteral("matchedText")] = nameDe;
        } else {
            item[QStringLiteral("matchedLanguage")] = QStringLiteral("Other");
            item[QStringLiteral("matchedText")] = nameEn;
        }
    } else {
        item[QStringLiteral("matchedInOtherLanguage")] = false;
        item[QStringLiteral("matchedLanguage")] = activeLang.toUpper();
        item[QStringLiteral("matchedText")] = displayName;
    }

    return item;
}

QString FoodDatabase::resolveSpeisDbPath(const QString &customPath)
{
    if (!customPath.isEmpty() && QFile::exists(customPath)) {
        return customPath;
    }

#ifdef QTSPEIS_WASM
    QString target = QStringLiteral("/speis.db");
    if (!QFile::exists(target)) {
        if (QFile::exists(QStringLiteral(":/speis.db"))) {
            QFile::copy(QStringLiteral(":/speis.db"), target);
            QFile::setPermissions(target, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
        }
    }
    return target;
#else
    const QStringList candidates = {
        QCoreApplication::applicationDirPath() + QStringLiteral("/speis.db"),
        QDir::currentPath() + QStringLiteral("/speis.db"),
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/speis.db")
    };
    for (const auto &cand : candidates) {
        if (QFile::exists(cand)) return cand;
    }

    QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(appData);
    QString target = appData + QStringLiteral("/speis.db");
    if (!QFile::exists(target) && QFile::exists(QStringLiteral(":/speis.db"))) {
        QFile::copy(QStringLiteral(":/speis.db"), target);
        QFile::setPermissions(target, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadUser | QFileDevice::WriteUser);
    }
    return target;
#endif
}

FoodDatabase::FoodDatabase(QObject *parent)
    : QObject(parent)
{
    m_connectionName = QString("FoodDb_%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    initDatabase();
}

FoodDatabase::~FoodDatabase()
{
    if (QSqlDatabase::contains(m_connectionName)) {
        QSqlDatabase::database(m_connectionName).close();
        QSqlDatabase::removeDatabase(m_connectionName);
    }
}

void FoodDatabase::setCurrentLanguage(const QString &lang)
{
    QString l = lang.trimmed().toLower();
    if (l != m_currentLanguage && !l.isEmpty()) {
        m_currentLanguage = l;
        emit languageChanged(m_currentLanguage);
    }
}

bool FoodDatabase::initDatabase(const QString &customPath)
{
    if (QSqlDatabase::contains(m_connectionName)) {
        QSqlDatabase::database(m_connectionName).close();
        QSqlDatabase::removeDatabase(m_connectionName);
    }

    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_dbPath = resolveSpeisDbPath(customPath);
    db.setDatabaseName(m_dbPath);

    if (!db.open()) {
        qWarning() << "Failed to open Food Database at" << m_dbPath << ":" << db.lastError().text();
        emit errorOccurred(db.lastError().text());
        return false;
    }

    // Check if the database has the normalized schema (foods + food_nutrients) and ensure v_foods view is up to date
    QSqlQuery checkTables(QStringLiteral("SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name IN ('foods', 'food_nutrients');"), db);
    bool hasNormalizedTables = (checkTables.next() && checkTables.value(0).toInt() >= 2);

    bool hasVFoods = false;
    if (hasNormalizedTables) {
        QSqlQuery qDrop(db);
        qDrop.exec(QStringLiteral("DROP VIEW IF EXISTS v_foods;"));
    } else {
        QSqlQuery checkQ(QStringLiteral("SELECT count(*) FROM sqlite_master WHERE type IN ('view', 'table') AND name = 'v_foods';"), db);
        if (checkQ.next() && checkQ.value(0).toInt() > 0) {
            hasVFoods = true;
        }
    }

    if (!hasVFoods) {
        if (hasNormalizedTables) {
            QSqlQuery qView(db);
            qView.exec(QStringLiteral(
                "CREATE VIEW IF NOT EXISTS v_foods AS "
                "SELECT f.id, "
                "       f.name_en AS name, "
                "       f.name_de AS name_de, "
                "       f.name_en AS name_en, "
                "       '' AS name_fr, '' AS name_es, '' AS name_it, "
                "       f.category, "
                "       '' AS category_de, '' AS category_fr, '' AS category_es, '' AS category_it, "
                "       f.meal_role, f.gi_class, f.gastric_emptying_hours, "
                "       COALESCE(fn.calories_kcal, 0.0) AS calories, "
                "       COALESCE(fn.carbs_g, 0.0) AS carbs, "
                "       COALESCE(fn.protein_g, 0.0) AS protein, "
                "       COALESCE(fn.fat_g, 0.0) AS fat, "
                "       COALESCE(fn.fiber_g, 0.0) AS fiber, "
                "       COALESCE(fn.fat_saturated_g, 0.0) AS sat_fat, "
                "       COALESCE(fn.fat_monounsaturated_g, 0.0) AS mufa, "
                "       COALESCE(fn.fat_polyunsaturated_g, 0.0) AS pufa, "
                "       COALESCE(fn.omega_3_g, 0.0) AS omega_3, "
                "       COALESCE(fn.omega_6_g, 0.0) AS omega_6, "
                "       COALESCE(fn.calcium_mg, 0.0) AS calcium, "
                "       COALESCE(fn.iron_mg, 0.0) AS iron, "
                "       COALESCE(fn.zinc_mg, 0.0) AS zinc, "
                "       COALESCE(fn.copper_mg, 0.0) AS copper, "
                "       COALESCE(fn.magnesium_mg, 0.0) AS magnesium, "
                "       COALESCE(fn.potassium_mg, 0.0) AS potassium, "
                "       COALESCE(fn.sodium_mg, 0.0) AS sodium, "
                "       COALESCE(fn.vitamin_a_ug, 0.0) AS vitamin_a, "
                "       COALESCE(fn.vitamin_c_mg, 0.0) AS vitamin_c, "
                "       COALESCE(fn.vitamin_d_ug, 0.0) AS vitamin_d, "
                "       COALESCE(fn.vitamin_e_mg, 0.0) AS vitamin_e, "
                "       COALESCE(fn.vitamin_k_ug, 0.0) AS vitamin_k, "
                "       COALESCE(fn.thiamine_mg, 0.0) AS thiamine, "
                "       COALESCE(fn.leucine_g, 0.0) AS leucine, "
                "       COALESCE(fn.tryptophan_g, 0.0) AS tryptophan, "
                "       COALESCE(fb.iron_type, 'none') AS iron_type, "
                "       COALESCE(fb.is_dairy_calcium, 0) AS is_dairy_calcium, "
                "       COALESCE(fb.polyphenol_level, 0) AS polyphenol_level, "
                "       COALESCE(fb.contains_caffeine, 0) AS contains_caffeine, "
                "       COALESCE(fb.phytate_mg, 0.0) AS phytate_mg, "
                "       COALESCE(fb.oxalate_mg, 0.0) AS oxalate_mg, "
                "       COALESCE(fb.is_viscous_fiber, 0) AS is_viscous_fiber, "
                "       COALESCE(fb.is_nightshade, 0) AS is_nightshade, "
                "       COALESCE(fb.is_seed, 0) AS is_seed, "
                "       COALESCE(fb.fodmap_level, 'low') AS fodmap_level, "
                "       COALESCE(fb.is_fermented, 0) AS is_fermented, "
                "       COALESCE(fb.has_phosvitin, 0) AS has_phosvitin, "
                "       CASE "
                "           WHEN f.name_en LIKE '%Pineapple%' OR f.name_de LIKE '%Ananas%' THEN '🍍' "
                "           WHEN f.name_en LIKE '%Pear%' OR f.name_de LIKE '%Birne%' THEN '🍐' "
                "           WHEN f.name_en LIKE '%Apple%' OR f.name_de LIKE '%Apfel%' OR f.name_de LIKE '%Äpfel%' THEN '🍎' "
                "           WHEN f.name_en LIKE '%Banana%' OR f.name_de LIKE '%Banane%' THEN '🍌' "
                "           WHEN f.name_en LIKE '%Strawberry%' OR f.name_de LIKE '%Erdbeer%' THEN '🍓' "
                "           WHEN f.name_en LIKE '%Cherry%' OR f.name_de LIKE '%Kirsch%' THEN '🍒' "
                "           WHEN f.name_en LIKE '%Berry%' OR f.name_en LIKE '%Berries%' OR f.name_en LIKE '%Blueberry%' OR f.name_de LIKE '%Beere%' THEN '🫐' "
                "           WHEN f.name_en LIKE '%Lemon%' OR f.name_en LIKE '%Lime%' OR f.name_de LIKE '%Zitrone%' OR f.name_de LIKE '%Limette%' THEN '🍋' "
                "           WHEN f.name_en LIKE '%Orange%' OR f.name_en LIKE '%Mandarin%' OR f.name_en LIKE '%Grapefruit%' OR f.name_de LIKE '%Orange%' OR f.name_de LIKE '%Mandarine%' THEN '🍊' "
                "           WHEN f.name_en LIKE '%Peach%' OR f.name_en LIKE '%Apricot%' OR f.name_en LIKE '%Plum%' OR f.name_de LIKE '%Pfirsich%' OR f.name_de LIKE '%Aprikose%' OR f.name_de LIKE '%Pflaume%' THEN '🍑' "
                "           WHEN f.name_en LIKE '%Grape%' OR f.name_en LIKE '%Raisin%' OR f.name_de LIKE '%Traube%' OR f.name_de LIKE '%Rosine%' THEN '🍇' "
                "           WHEN f.name_en LIKE '%Melon%' OR f.name_de LIKE '%Melone%' THEN '🍉' "
                "           WHEN f.name_en LIKE '%Kiwi%' OR f.name_de LIKE '%Kiwi%' THEN '🥝' "
                "           WHEN f.name_en LIKE '%Mango%' OR f.name_de LIKE '%Mango%' THEN '🥭' "
                "           WHEN f.name_en LIKE '%Avocado%' OR f.name_de LIKE '%Avocado%' THEN '🥑' "
                "           WHEN f.name_en LIKE '%Sweet potato%' OR f.name_de LIKE '%Süßkartoffel%' THEN '🍠' "
                "           WHEN f.name_en LIKE '%Potato%' OR f.name_de LIKE '%Kartoffel%' THEN '🥔' "
                "           WHEN f.name_en LIKE '%Carrot%' OR f.name_en LIKE '%Parsnip%' OR f.name_de LIKE '%Karotte%' OR f.name_de LIKE '%Möhre%' OR f.name_de LIKE '%Pastinake%' THEN '🥕' "
                "           WHEN f.name_en LIKE '%Tomato%' OR f.name_de LIKE '%Tomate%' THEN '🍅' "
                "           WHEN f.name_en LIKE '%Pepper%' OR f.name_de LIKE '%Paprika%' THEN '🫑' "
                "           WHEN f.name_en LIKE '%Zucchini%' OR f.name_en LIKE '%Cucumber%' OR f.name_de LIKE '%Zucchini%' OR f.name_de LIKE '%Gurke%' THEN '🥒' "
                "           WHEN f.name_en LIKE '%Broccoli%' OR f.name_en LIKE '%Cauliflower%' OR f.name_de LIKE '%Brokkoli%' OR f.name_de LIKE '%Blumenkohl%' OR f.name_de LIKE '%Rosenkohl%' OR f.name_de LIKE '%Kohlrabi%' THEN '🥦' "
                "           WHEN f.name_en LIKE '%Spinach%' OR f.name_en LIKE '%Kale%' OR f.name_en LIKE '%Cabbage%' OR f.name_de LIKE '%Spinat%' OR f.name_de LIKE '%Kohl%' OR f.name_de LIKE '%Mangold%' OR f.name_de LIKE '%Sauerkraut%' THEN '🥬' "
                "           WHEN f.name_en LIKE '%Salad%' OR f.name_en LIKE '%Lettuce%' OR f.name_de LIKE '%Salat%' OR f.name_de LIKE '%Rucola%' THEN '🥗' "
                "           WHEN f.name_en LIKE '%Onion%' OR f.name_en LIKE '%Leek%' OR f.name_de LIKE '%Zwiebel%' OR f.name_de LIKE '%Lauch%' OR f.name_de LIKE '%Porree%' THEN '🧅' "
                "           WHEN f.name_en LIKE '%Garlic%' OR f.name_de LIKE '%Knoblauch%' THEN '🧄' "
                "           WHEN f.name_en LIKE '%Mushroom%' OR f.name_de LIKE '%Pilz%' OR f.name_de LIKE '%Champignon%' OR f.name_de LIKE '%Pfifferling%' THEN '🍄' "
                "           WHEN f.name_en LIKE '%Corn%' OR f.name_de LIKE '%Mais%' THEN '🌽' "
                "           WHEN f.name_en LIKE '%Eggplant%' OR f.name_de LIKE '%Aubergine%' THEN '🍆' "
                "           WHEN f.name_en LIKE '%Oat%' OR f.name_en LIKE '%Porridge%' OR f.name_en LIKE '%Muesli%' OR f.name_en LIKE '%Quinoa%' OR f.name_en LIKE '%Millet%' OR f.name_en LIKE '%Buckwheat%' OR f.name_de LIKE '%Hafer%' OR f.name_de LIKE '%Müsli%' OR f.name_de LIKE '%Hirse%' OR f.name_de LIKE '%Buchweizen%' OR f.name_de LIKE '%Flocken%' THEN '🥣' "
                "           WHEN f.name_en LIKE '%Bread%' OR f.name_en LIKE '%Roll%' OR f.name_en LIKE '%Toast%' OR f.name_de LIKE '%Brot%' OR f.name_de LIKE '%Brötchen%' THEN '🍞' "
                "           WHEN f.name_en LIKE '%Rice%' OR f.name_de LIKE '%Reis%' THEN '🍚' "
                "           WHEN f.name_en LIKE '%Pasta%' OR f.name_en LIKE '%Spaghetti%' OR f.name_en LIKE '%Noodle%' OR f.name_de LIKE '%Nudel%' OR f.name_de LIKE '%Spaghetti%' THEN '🍝' "
                "           WHEN f.name_en LIKE '%Lentil%' OR f.name_en LIKE '%Bean%' OR f.name_en LIKE '%Chickpea%' OR f.name_en LIKE '%Pea%' OR f.name_de LIKE '%Linse%' OR f.name_de LIKE '%Bohne%' OR f.name_de LIKE '%Kichererbse%' OR f.name_de LIKE '%Erbse%' THEN '🫘' "
                "           WHEN f.name_en LIKE '%Tofu%' OR f.name_en LIKE '%Tempeh%' OR f.name_en LIKE '%Butter%' OR f.name_de LIKE '%Butter%' OR f.name_de LIKE '%Margarine%' OR f.name_de LIKE '%Schmalz%' THEN '🧈' "
                "           WHEN f.name_en LIKE '%Olive oil%' OR f.name_en LIKE '%Oil%' OR f.name_de LIKE '%Öl%' THEN '🫒' "
                "           WHEN f.name_en LIKE '%Walnut%' OR f.name_en LIKE '%Nut%' OR f.name_en LIKE '%Almond%' OR f.name_en LIKE '%Cashew%' OR f.name_en LIKE '%Peanut%' OR f.name_en LIKE '%Pistachio%' OR f.name_de LIKE '%Nuss%' OR f.name_de LIKE '%Nüsse%' OR f.name_de LIKE '%Mandel%' OR f.name_de LIKE '%Cashew%' OR f.name_de LIKE '%Pistazie%' OR f.name_de LIKE '%Maroni%' THEN '🥜' "
                "           WHEN f.name_en LIKE '%Seed%' OR f.name_en LIKE '%Psyllium%' OR f.name_de LIKE '%Samen%' OR f.name_de LIKE '%Kerne%' THEN '🌱' "
                "           WHEN f.name_en LIKE '%Beef%' OR f.name_en LIKE '%Steak%' OR f.name_en LIKE '%Pork%' OR f.name_en LIKE '%Veal%' OR f.name_en LIKE '%Lamb%' OR f.name_en LIKE '%Ham%' OR f.name_de LIKE '%Rind%' OR f.name_de LIKE '%Schwein%' OR f.name_de LIKE '%Kalb%' OR f.name_de LIKE '%Lamm%' OR f.name_de LIKE '%Schinken%' OR f.name_de LIKE '%Wurst%' THEN '🥩' "
                "           WHEN f.name_en LIKE '%Chicken%' OR f.name_en LIKE '%Turkey%' OR f.name_en LIKE '%Duck%' OR f.name_de LIKE '%Hähnchen%' OR f.name_de LIKE '%Huhn%' OR f.name_de LIKE '%Pute%' OR f.name_de LIKE '%Ente%' OR f.name_de LIKE '%Gans%' THEN '🍗' "
                "           WHEN f.name_en LIKE '%Shrimp%' OR f.name_en LIKE '%Prawn%' OR f.name_de LIKE '%Garnele%' OR f.name_de LIKE '%Krabbe%' OR f.name_de LIKE '%Muschel%' THEN '🦐' "
                "           WHEN f.name_en LIKE '%Salmon%' OR f.name_en LIKE '%Tuna%' OR f.name_en LIKE '%Fish%' OR f.name_en LIKE '%Trout%' OR f.name_en LIKE '%Cod%' OR f.name_en LIKE '%Herring%' OR f.name_en LIKE '%Mackerel%' OR f.name_de LIKE '%Lachs%' OR f.name_de LIKE '%Thunfisch%' OR f.name_de LIKE '%Forelle%' OR f.name_de LIKE '%Kabeljau%' OR f.name_de LIKE '%Hering%' OR f.name_de LIKE '%Makrele%' OR f.name_de LIKE '%Fisch%' THEN '🐟' "
                "           WHEN f.name_en LIKE '%Egg%' OR f.name_de LIKE '%Ei%' OR f.name_de LIKE '%Hühnerei%' THEN '🥚' "
                "           WHEN f.name_en LIKE '%Cheese%' OR f.name_en LIKE '%Mozzarella%' OR f.name_en LIKE '%Parmesan%' OR f.name_en LIKE '%Gouda%' OR f.name_en LIKE '%Feta%' OR f.name_de LIKE '%Käse%' OR f.name_de LIKE '%Camembert%' OR f.name_de LIKE '%Brie%' THEN '🧀' "
                "           WHEN f.name_en LIKE '%Yogurt%' OR f.name_en LIKE '%Milk%' OR f.name_en LIKE '%Quark%' OR f.name_en LIKE '%Skyr%' OR f.name_en LIKE '%Kefir%' OR f.name_de LIKE '%Joghurt%' OR f.name_de LIKE '%Milch%' OR f.name_de LIKE '%Quark%' OR f.name_de LIKE '%Sahne%' OR f.name_de LIKE '%Schmand%' THEN '🥛' "
                "           WHEN f.name_en LIKE '%Coffee%' OR f.name_en LIKE '%Espresso%' OR f.name_de LIKE '%Kaffee%' THEN '☕' "
                "           WHEN f.name_en LIKE '%Tea%' OR f.name_de LIKE '%Tee%' THEN '🍵' "
                "           WHEN f.name_en LIKE '%Whey%' OR f.name_en LIKE '%Protein%' OR f.name_en LIKE '%Juice%' OR f.name_de LIKE '%Saft%' THEN '🥤' "
                "           WHEN f.name_en LIKE '%Water%' OR f.name_de LIKE '%Wasser%' THEN '💧' "
                "           WHEN f.name_en LIKE '%Honey%' OR f.name_en LIKE '%Syrup%' OR f.name_de LIKE '%Honig%' OR f.name_de LIKE '%Sirup%' THEN '🍯' "
                "           WHEN f.name_en LIKE '%Chocolate%' OR f.name_en LIKE '%Cocoa%' OR f.name_de LIKE '%Schokolade%' OR f.name_de LIKE '%Kakao%' THEN '🍫' "
                "           WHEN f.category LIKE '%Getreide%' OR f.category LIKE '%Cereal%' OR f.category LIKE '%Grain%' THEN '🌾' "
                "           WHEN f.category LIKE '%Fleisch%' OR f.category LIKE '%Meat%' THEN '🥩' "
                "           WHEN f.category LIKE '%Fisch%' OR f.category LIKE '%Fish%' THEN '🐟' "
                "           WHEN f.category LIKE '%Eier%' OR f.category LIKE '%Egg%' THEN '🥚' "
                "           WHEN f.category LIKE '%Obst%' OR f.category LIKE '%Fruit%' THEN '🍎' "
                "           WHEN f.category LIKE '%Gemüse%' OR f.category LIKE '%Vegetable%' THEN '🥦' "
                "           WHEN f.category LIKE '%Salat%' OR f.category LIKE '%Salad%' THEN '🥗' "
                "           WHEN f.category LIKE '%Hülsenfrüchte%' OR f.category LIKE '%Legume%' THEN '🫘' "
                "           WHEN f.category LIKE '%Nüsse%' OR f.category LIKE '%Nut%' OR f.category LIKE '%Samen%' THEN '🥜' "
                "           WHEN f.category LIKE '%Öle%' OR f.category LIKE '%Fette%' OR f.category LIKE '%Oil%' THEN '🫒' "
                "           WHEN f.category LIKE '%Kräuter%' OR f.category LIKE '%Herb%' OR f.category LIKE '%Spice%' THEN '🌿' "
                "           WHEN f.category LIKE '%Milch%' OR f.category LIKE '%Dairy%' THEN '🥛' "
                "           WHEN f.category LIKE '%Süß%' OR f.category LIKE '%Sweet%' THEN '🍯' "
                "           WHEN f.category LIKE '%Getränk%' OR f.category LIKE '%Beverage%' THEN '🥤' "
                "           ELSE '🥗' "
                "       END AS icon, "
                "       CASE "
                "           WHEN f.name_en LIKE '%Egg%' THEN 50 "
                "           WHEN f.name_en LIKE '%Bread%' THEN 50 "
                "           WHEN f.name_en LIKE '%Oat%' THEN 80 "
                "           WHEN f.name_en LIKE '%Oil%' OR f.name_en LIKE '%Butter%' THEN 10 "
                "           WHEN f.name_en LIKE '%Walnut%' OR f.name_en LIKE '%Nut%' OR f.name_en LIKE '%Seed%' OR f.name_en LIKE '%Cashew%' OR f.name_en LIKE '%Almond%' THEN 20 "
                "           WHEN f.name_en LIKE '%Coffee%' OR f.name_en LIKE '%Tea%' THEN 200 "
                "           WHEN f.name_en LIKE '%Milk%' OR f.name_en LIKE '%Yogurt%' THEN 150 "
                "           WHEN f.name_en LIKE '%Psyllium%' THEN 5 "
                "           WHEN f.name_en LIKE '%Whey%' THEN 25 "
                "           ELSE 100 "
                "       END AS serving_size, "
                "       'g' AS serving_unit, "
                "       '' AS barcode "
                "FROM foods f "
                "LEFT JOIN food_nutrients fn ON f.id = fn.food_id AND fn.preparation_state = ( "
                "    SELECT fn2.preparation_state FROM food_nutrients fn2 WHERE fn2.food_id = f.id "
                "    ORDER BY CASE fn2.preparation_state WHEN 'raw' THEN 1 WHEN 'cooked' THEN 2 WHEN 'boiled' THEN 3 ELSE 4 END LIMIT 1 "
                ") "
                "LEFT JOIN food_biochem fb ON f.id = fb.food_id;"
            ));
            hasVFoods = true;
        } else {
            // Fallback for standalone database without v_foods
            QSqlQuery q(db);
            q.exec(QStringLiteral(
                "CREATE TABLE IF NOT EXISTS foods ("
                "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "name TEXT NOT NULL, "
                "name_de TEXT DEFAULT '', "
                "name_fr TEXT DEFAULT '', "
                "name_es TEXT DEFAULT '', "
                "name_it TEXT DEFAULT '', "
                "category TEXT DEFAULT 'Custom', "
                "category_de TEXT DEFAULT 'Sonstiges', "
                "category_fr TEXT DEFAULT 'Divers', "
                "category_es TEXT DEFAULT 'Varios', "
                "category_it TEXT DEFAULT 'Varie', "
                "calories REAL NOT NULL, "
                "carbs REAL NOT NULL, "
                "protein REAL NOT NULL, "
                "fat REAL NOT NULL, "
                "fiber REAL DEFAULT 0.0, "
                "serving_size REAL DEFAULT 100, "
                "serving_unit TEXT DEFAULT 'g', "
                "icon TEXT DEFAULT '🍽️', "
                "barcode TEXT"
                ");"
            ));
            if (totalCount() == 0) {
                populateStarterCatalog();
            }
        }
    }

    m_initialized = true;
    emit databaseChanged();
    return true;
}

bool FoodDatabase::loadExternalDatabase(const QString &filePath)
{
    if (!QFile::exists(filePath)) {
        emit errorOccurred(QStringLiteral("Database file does not exist: %1").arg(filePath));
        return false;
    }
    return initDatabase(filePath);
}

int FoodDatabase::totalCount() const
{
    if (!QSqlDatabase::contains(m_connectionName)) return 0;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(QStringLiteral("SELECT COUNT(*) FROM v_foods;"), db);
    if (!q.exec() || !q.next()) {
        QSqlQuery fallback(QStringLiteral("SELECT COUNT(*) FROM foods;"), db);
        if (fallback.next()) return fallback.value(0).toInt();
        return 0;
    }
    return q.value(0).toInt();
}

QVariantList FoodDatabase::search(const QString &query, int limit, const QString &langOverride)
{
    QVariantList results;
    if (!QSqlDatabase::contains(m_connectionName)) return results;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);

    QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();
    QString activeNameCol = nameColForLang(activeLang);
    QString activeCatCol = catColForLang(activeLang);

    QString trimmed = query.trimmed();
    QSqlQuery q(db);

    if (trimmed.isEmpty()) {
        q.prepare(QStringLiteral(
            "SELECT * FROM v_foods ORDER BY category ASC, name ASC LIMIT :limit;"
        ));
        q.bindValue(QStringLiteral(":limit"), limit);
    } else {
        QString sql = QStringLiteral(
            "SELECT *, "
            "       CASE "
            "           WHEN LOWER(COALESCE(NULLIF(%1, ''), name)) LIKE :prefix THEN 1 "
            "           WHEN LOWER(COALESCE(NULLIF(%1, ''), name)) LIKE :contains THEN 2 "
            "           WHEN LOWER(COALESCE(NULLIF(%2, ''), category)) LIKE :contains OR barcode = :exact THEN 3 "
            "           WHEN LOWER(name) LIKE :prefix OR LOWER(name_de) LIKE :prefix THEN 4 "
            "           WHEN LOWER(name) LIKE :contains OR LOWER(name_de) LIKE :contains THEN 5 "
            "           ELSE 6 "
            "       END AS rank "
            "FROM v_foods "
            "WHERE LOWER(COALESCE(NULLIF(%1, ''), name)) LIKE :contains "
            "   OR barcode = :exact "
            "   OR LOWER(name) LIKE :contains "
            "   OR LOWER(name_de) LIKE :contains "
            "   OR LOWER(category) LIKE :contains "
            "   OR LOWER(category_de) LIKE :contains "
            "ORDER BY rank ASC, COALESCE(NULLIF(%1, ''), name) ASC "
            "LIMIT :limit;"
        ).arg(activeNameCol, activeCatCol);

        q.prepare(sql);
        QString lower = trimmed.toLower();
        q.bindValue(QStringLiteral(":prefix"), lower + QStringLiteral("%"));
        q.bindValue(QStringLiteral(":contains"), QStringLiteral("%") + lower + QStringLiteral("%"));
        q.bindValue(QStringLiteral(":exact"), trimmed);
        q.bindValue(QStringLiteral(":limit"), limit);
    }

    if (q.exec()) {
        QString lowerQuery = trimmed.toLower();
        while (q.next()) {
            results.append(recordToFoodMap(q, activeLang, lowerQuery));
        }
    } else {
        // Fallback for standalone database querying foods table directly
        qWarning() << "Search on v_foods error, trying foods table:" << q.lastError().text();
        q.prepare(QStringLiteral("SELECT * FROM foods LIMIT :limit;"));
        q.bindValue(QStringLiteral(":limit"), limit);
        if (q.exec()) {
            while (q.next()) {
                results.append(recordToFoodMap(q, activeLang, trimmed.toLower()));
            }
        }
    }

    return results;
}

QStringList FoodDatabase::allCategories(const QString &langOverride) const
{
    QStringList cats;
    if (!QSqlDatabase::contains(m_connectionName)) return cats;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();

    q.prepare(QStringLiteral("SELECT DISTINCT category FROM v_foods WHERE category IS NOT NULL AND category != '' ORDER BY category ASC;"));
    if (q.exec()) {
        while (q.next()) {
            QString c = q.value(0).toString().trimmed();
            QString loc = localizeCategory(c, activeLang);
            if (!loc.isEmpty() && !cats.contains(loc)) {
                cats.append(loc);
            }
        }
    }
    return cats;
}

QVariantList FoodDatabase::exploreFoods(const QString &searchQuery,
                                        const QString &categoryFilter,
                                        const QString &sortBy,
                                        bool sortAscending,
                                        int limit,
                                        const QString &langOverride)
{
    QVariantList results;
    if (!QSqlDatabase::contains(m_connectionName)) return results;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);

    QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();
    QString activeNameCol = nameColForLang(activeLang);

    QStringList whereClauses;
    QMap<QString, QVariant> bindings;

    QString trimmedQuery = searchQuery.trimmed();
    if (!trimmedQuery.isEmpty()) {
        whereClauses.append(QStringLiteral(
            "(LOWER(COALESCE(NULLIF(%1, ''), name)) LIKE :searchQuery "
            " OR LOWER(name) LIKE :searchQuery "
            " OR LOWER(name_de) LIKE :searchQuery "
            " OR barcode = :exactQuery)"
        ).arg(activeNameCol));
        bindings.insert(QStringLiteral(":searchQuery"), QStringLiteral("%%1%").arg(trimmedQuery.toLower()));
        bindings.insert(QStringLiteral(":exactQuery"), trimmedQuery);
    }

    QString trimmedCat = categoryFilter.trimmed();
    if (!trimmedCat.isEmpty() && trimmedCat.compare(QStringLiteral("All"), Qt::CaseInsensitive) != 0 && trimmedCat.compare(QStringLiteral("Alle"), Qt::CaseInsensitive) != 0) {
        QString dbCat = mapToDbCategory(trimmedCat);
        if (!dbCat.isEmpty()) {
            whereClauses.append(QStringLiteral("(category = :catFilter OR category LIKE :catFilterLike)"));
            bindings.insert(QStringLiteral(":catFilter"), dbCat);
            bindings.insert(QStringLiteral(":catFilterLike"), QStringLiteral("%%1%").arg(dbCat));
        }
    }

    QString whereSql = whereClauses.isEmpty() ? QString() : QStringLiteral("WHERE ") + whereClauses.join(QStringLiteral(" AND "));

    QString orderCol = QStringLiteral("COALESCE(NULLIF(%1, ''), name)").arg(activeNameCol);
    QString s = sortBy.trimmed().toLower();
    if (s == QStringLiteral("calories") || s == QStringLiteral("energy")) orderCol = QStringLiteral("calories");
    else if (s == QStringLiteral("protein")) orderCol = QStringLiteral("protein");
    else if (s == QStringLiteral("carbs")) orderCol = QStringLiteral("carbs");
    else if (s == QStringLiteral("fat")) orderCol = QStringLiteral("fat");
    else if (s == QStringLiteral("fiber")) orderCol = QStringLiteral("fiber");
    else if (s == QStringLiteral("calcium")) orderCol = QStringLiteral("calcium");
    else if (s == QStringLiteral("iron")) orderCol = QStringLiteral("iron");
    else if (s == QStringLiteral("magnesium")) orderCol = QStringLiteral("magnesium");
    else if (s == QStringLiteral("potassium")) orderCol = QStringLiteral("potassium");
    else if (s == QStringLiteral("vitamin_c") || s == QStringLiteral("vitaminc")) orderCol = QStringLiteral("vitamin_c");
    else if (s == QStringLiteral("omega_3") || s == QStringLiteral("omega3")) orderCol = QStringLiteral("omega_3");

    QString dir = sortAscending ? QStringLiteral("ASC") : QStringLiteral("DESC");

    QString querySql = QStringLiteral("SELECT * FROM v_foods %1 ORDER BY %2 %3 LIMIT :limit;")
                           .arg(whereSql, orderCol, dir);

    QSqlQuery q(db);
    q.prepare(querySql);
    for (auto it = bindings.begin(); it != bindings.end(); ++it) {
        q.bindValue(it.key(), it.value());
    }
    q.bindValue(QStringLiteral(":limit"), limit > 0 ? limit : 150);

    if (q.exec()) {
        while (q.next()) {
            results.append(recordToFoodMap(q, activeLang));
        }
    } else {
        qWarning() << "exploreFoods error:" << q.lastError().text();
    }

    return results;
}

QVariantMap FoodDatabase::getFoodById(int id, const QString &langOverride)
{
    QVariantMap item;
    if (!QSqlDatabase::contains(m_connectionName)) return item;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT * FROM v_foods WHERE id = :id LIMIT 1;"));
    q.bindValue(QStringLiteral(":id"), id);
    if (!q.exec() || !q.next()) {
        q.prepare(QStringLiteral("SELECT * FROM foods WHERE id = :id LIMIT 1;"));
        q.bindValue(QStringLiteral(":id"), id);
        if (q.exec() && q.next()) {
            QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();
            return recordToFoodMap(q, activeLang);
        }
        return item;
    }
    QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();
    return recordToFoodMap(q, activeLang);
}

QVariantMap FoodDatabase::getFoodByBarcode(const QString &barcode, const QString &langOverride)
{
    QVariantMap item;
    if (barcode.trimmed().isEmpty() || !QSqlDatabase::contains(m_connectionName)) return item;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT * FROM v_foods WHERE barcode = :barcode LIMIT 1;"));
    q.bindValue(QStringLiteral(":barcode"), barcode.trimmed());
    if (!q.exec() || !q.next()) {
        q.prepare(QStringLiteral("SELECT * FROM foods WHERE barcode = :barcode LIMIT 1;"));
        q.bindValue(QStringLiteral(":barcode"), barcode.trimmed());
        if (q.exec() && q.next()) {
            QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();
            return recordToFoodMap(q, activeLang);
        }
        return item;
    }
    QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();
    return recordToFoodMap(q, activeLang);
}

QVariantMap FoodDatabase::findFoodByName(const QString &name, const QString &langOverride)
{
    QVariantMap item;
    QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || !QSqlDatabase::contains(m_connectionName)) return item;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    QString activeLang = langOverride.isEmpty() ? m_currentLanguage : langOverride.trimmed().toLower();

    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "SELECT * FROM v_foods "
        "WHERE LOWER(name) = :lower "
        "   OR LOWER(name_de) = :lower "
        "   OR LOWER(name_en) = :lower "
        "LIMIT 1;"
    ));
    q.bindValue(QStringLiteral(":lower"), trimmed.toLower());

    if (q.exec() && q.next()) {
        return recordToFoodMap(q, activeLang);
    }

    // Secondary fallback: contains match
    q.prepare(QStringLiteral(
        "SELECT * FROM v_foods "
        "WHERE LOWER(name) LIKE :contains "
        "   OR LOWER(name_de) LIKE :contains "
        "   OR LOWER(name_en) LIKE :contains "
        "LIMIT 1;"
    ));
    q.bindValue(QStringLiteral(":contains"), QStringLiteral("%%1%").arg(trimmed.toLower()));
    if (q.exec() && q.next()) {
        return recordToFoodMap(q, activeLang);
    }

    return item;
}

bool FoodDatabase::addFood(const QVariantMap &food)
{
    if (!QSqlDatabase::contains(m_connectionName)) return false;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);

    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "INSERT INTO foods (name_de, name_en, category, meal_role, gi_class, gastric_emptying_hours) "
        "VALUES (:name_de, :name_en, :category, 'snack', :gi_class, 2.0);"
    ));
    QString nameDe = food.value(QStringLiteral("nameDe"), food.value(QStringLiteral("name"))).toString();
    QString nameEn = food.value(QStringLiteral("nameEn"), food.value(QStringLiteral("name"))).toString();
    QString cat = food.value(QStringLiteral("category"), QStringLiteral("Custom")).toString();
    q.bindValue(QStringLiteral(":name_de"), nameDe);
    q.bindValue(QStringLiteral(":name_en"), nameEn);
    q.bindValue(QStringLiteral(":category"), cat);
    q.bindValue(QStringLiteral(":gi_class"), food.value(QStringLiteral("giClass"), QStringLiteral("medium")).toString());

    if (!q.exec()) {
        // Fallback for legacy foods table
        q.prepare(QStringLiteral(
            "INSERT INTO foods (name, name_de, category, calories, carbs, protein, fat, fiber, serving_size, serving_unit, icon, barcode) "
            "VALUES (:name, :name_de, :category, :calories, :carbs, :protein, :fat, :fiber, :serving_size, :serving_unit, :icon, :barcode);"
        ));
        q.bindValue(QStringLiteral(":name"), nameEn);
        q.bindValue(QStringLiteral(":name_de"), nameDe);
        q.bindValue(QStringLiteral(":category"), cat);
        q.bindValue(QStringLiteral(":calories"), food.value(QStringLiteral("calories"), 0.0).toDouble());
        q.bindValue(QStringLiteral(":carbs"), food.value(QStringLiteral("carbs"), 0.0).toDouble());
        q.bindValue(QStringLiteral(":protein"), food.value(QStringLiteral("protein"), 0.0).toDouble());
        q.bindValue(QStringLiteral(":fat"), food.value(QStringLiteral("fat"), 0.0).toDouble());
        q.bindValue(QStringLiteral(":fiber"), food.value(QStringLiteral("fiber"), 0.0).toDouble());
        q.bindValue(QStringLiteral(":serving_size"), food.value(QStringLiteral("servingSize"), 100.0).toDouble());
        q.bindValue(QStringLiteral(":serving_unit"), food.value(QStringLiteral("servingUnit"), QStringLiteral("g")).toString());
        q.bindValue(QStringLiteral(":icon"), food.value(QStringLiteral("icon"), QStringLiteral("🍽️")).toString());
        q.bindValue(QStringLiteral(":barcode"), food.value(QStringLiteral("barcode")).toString());
        bool okLegacy = q.exec();
        if (okLegacy) emit databaseChanged();
        return okLegacy;
    }

    int foodId = q.lastInsertId().toInt();
    if (foodId > 0) {
        QSqlQuery qNut(db);
        qNut.prepare(QStringLiteral(
            "INSERT INTO food_nutrients (food_id, preparation_state, calories_kcal, carbs_g, protein_g, fat_g, fiber_g, "
            "fat_saturated_g, fat_monounsaturated_g, fat_polyunsaturated_g, omega_3_g, omega_6_g, "
            "calcium_mg, iron_mg, zinc_mg, copper_mg, magnesium_mg, potassium_mg, sodium_mg, "
            "vitamin_a_ug, vitamin_c_mg, vitamin_d_ug, vitamin_e_mg, vitamin_k_ug, thiamine_mg, leucine_g, tryptophan_g) "
            "VALUES (:fid, 'raw', :cal, :carb, :prot, :fat, :fib, "
            ":sat, :mufa, :pufa, :o3, :o6, "
            ":ca, :fe, :zn, :cu, :mg, :k, :na, "
            ":va, :vc, :vd, :ve, :vk, :thiam, :leu, :trp);"
        ));
        qNut.bindValue(QStringLiteral(":fid"), foodId);
        qNut.bindValue(QStringLiteral(":cal"), food.value(QStringLiteral("calories"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":carb"), food.value(QStringLiteral("carbs"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":prot"), food.value(QStringLiteral("protein"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":fat"), food.value(QStringLiteral("fat"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":fib"), food.value(QStringLiteral("fiber"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":sat"), food.value(QStringLiteral("satFat"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":mufa"), food.value(QStringLiteral("mufa"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":pufa"), food.value(QStringLiteral("pufa"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":o3"), food.value(QStringLiteral("omega3"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":o6"), food.value(QStringLiteral("omega6"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":ca"), food.value(QStringLiteral("calcium"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":fe"), food.value(QStringLiteral("iron"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":zn"), food.value(QStringLiteral("zinc"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":cu"), food.value(QStringLiteral("copper"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":mg"), food.value(QStringLiteral("magnesium"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":k"), food.value(QStringLiteral("potassium"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":na"), food.value(QStringLiteral("sodium"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":va"), food.value(QStringLiteral("vitaminA"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":vc"), food.value(QStringLiteral("vitaminC"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":vd"), food.value(QStringLiteral("vitaminD"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":ve"), food.value(QStringLiteral("vitaminE"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":vk"), food.value(QStringLiteral("vitaminK"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":thiam"), food.value(QStringLiteral("thiamine"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":leu"), food.value(QStringLiteral("leucine"), 0.0).toDouble());
        qNut.bindValue(QStringLiteral(":trp"), food.value(QStringLiteral("tryptophan"), 0.0).toDouble());
        qNut.exec();

        QSqlQuery qBio(db);
        qBio.prepare(QStringLiteral(
            "INSERT INTO food_biochem (food_id, iron_type, is_dairy_calcium, polyphenol_level, contains_caffeine, "
            "phytate_mg, oxalate_mg, is_viscous_fiber, is_nightshade, is_seed, fodmap_level, is_fermented, has_phosvitin) "
            "VALUES (:fid, :it, :idc, :poly, :caff, :phy, :ox, :vf, :ns, :seed, :fod, :ferm, :phos);"
        ));
        qBio.bindValue(QStringLiteral(":fid"), foodId);
        qBio.bindValue(QStringLiteral(":it"), food.value(QStringLiteral("ironType"), QStringLiteral("none")).toString());
        qBio.bindValue(QStringLiteral(":idc"), food.value(QStringLiteral("isDairyCalcium"), 0).toInt());
        qBio.bindValue(QStringLiteral(":poly"), food.value(QStringLiteral("polyphenolLevel"), 0).toInt());
        qBio.bindValue(QStringLiteral(":caff"), food.value(QStringLiteral("containsCaffeine"), 0).toInt());
        qBio.bindValue(QStringLiteral(":phy"), food.value(QStringLiteral("phytateMg"), 0.0).toDouble());
        qBio.bindValue(QStringLiteral(":ox"), food.value(QStringLiteral("oxalateMg"), 0.0).toDouble());
        qBio.bindValue(QStringLiteral(":vf"), food.value(QStringLiteral("isViscousFiber"), 0).toInt());
        qBio.bindValue(QStringLiteral(":ns"), food.value(QStringLiteral("isNightshade"), 0).toInt());
        qBio.bindValue(QStringLiteral(":seed"), food.value(QStringLiteral("isSeed"), 0).toInt());
        qBio.bindValue(QStringLiteral(":fod"), food.value(QStringLiteral("fodmapLevel"), QStringLiteral("low")).toString());
        qBio.bindValue(QStringLiteral(":ferm"), food.value(QStringLiteral("isFermented"), 0).toInt());
        qBio.bindValue(QStringLiteral(":phos"), food.value(QStringLiteral("hasPhosvitin"), 0).toInt());
        qBio.exec();
    }

    emit databaseChanged();
    return true;
}

void FoodDatabase::populateStarterCatalog()
{
    struct StarterFood {
        const char *name;      // English
        const char *name_de;   // Deutsch
        const char *name_fr;   // Français
        const char *name_es;   // Español
        const char *name_it;   // Italiano
        const char *category;  // English
        const char *cat_de;    // Deutsch
        const char *cat_fr;    // Français
        const char *cat_es;    // Español
        const char *cat_it;    // Italiano
        double calories;
        double carbs;
        double protein;
        double fat;
        double fiber;
        double serving;
        const char *unit;
        const char *icon;
        const char *barcode;
    };

    const StarterFood starter[] = {
        // Grains & Carbs
        { "Rolled Oats", "Haferflocken", "Flocons d'avoine", "Copos de avena", "Fiocchi d'avena", "Grains & Cereals", "Getreide & Zerealien", "Céréales", "Cereales", "Cereali", 379, 67.7, 13.2, 6.5, 10.1, 80, "g", "🥣", "4008400404127" },
        { "Sourdough Bread", "Sauerteigbrot", "Pain au levain", "Pan de masa madre", "Pane a lievitazione", "Bakery", "Bäckerei", "Boulangerie", "Panadería", "Panetteria", 260, 51.0, 9.0, 1.5, 3.0, 50, "g", "🍞", "" },
        { "Brown Rice (Cooked)", "Vollkornreis (gekocht)", "Riz complet (cuit)", "Arroz integral (cocido)", "Riso integrale (cotto)", "Grains & Cereals", "Getreide & Zerealien", "Céréales", "Cereales", "Cereali", 123, 25.6, 2.7, 1.0, 1.6, 150, "g", "🍚", "" },
        { "Jasmine Rice (Cooked)", "Jasminreis (gekocht)", "Riz jasmin (cuit)", "Arroz jazmín (cocido)", "Riso jasmine (cotto)", "Grains & Cereals", "Getreide & Zerealien", "Céréales", "Cereales", "Cereali", 130, 28.2, 2.7, 0.3, 0.4, 150, "g", "🍚", "" },
        { "Whole Wheat Pasta (Cooked)", "Vollkornnudeln (gekocht)", "Pâtes complètes (cuites)", "Pasta integral (cocida)", "Pasta integrale (cotta)", "Pasta & Noodles", "Pasta & Nudeln", "Pâtes", "Pasta", "Pasta", 149, 30.1, 5.3, 0.8, 4.5, 160, "g", "🍝", "" },
        { "Quinoa (Cooked)", "Quinoa (gekocht)", "Quinoa (cuit)", "Quinua (cocida)", "Quinoa (cotta)", "Grains & Cereals", "Getreide & Zerealien", "Céréales", "Cereales", "Cereali", 120, 21.3, 4.4, 1.9, 2.8, 140, "g", "🌾", "" },
        { "Baked Sweet Potato", "Gebackene Süßkartoffel", "Patate douce au four", "Batata asada", "Patata dolce al forno", "Produce & Roots", "Gemüse & Knollen", "Légumes", "Verduras", "Verdure", 90, 20.7, 2.0, 0.1, 3.3, 180, "g", "🍠", "" },
        { "Boiled Potatoes", "Salzkartoffeln", "Pommes de terre bouillies", "Patatas cocidas", "Patate lesse", "Produce & Roots", "Gemüse & Knollen", "Légumes", "Verduras", "Verdure", 87, 20.1, 1.9, 0.1, 1.8, 200, "g", "🥔", "" },
        { "Whole Grain Bagel", "Vollkorn-Bagel", "Bagel complet", "Bagel integral", "Bagel integrale", "Bakery", "Bäckerei", "Boulangerie", "Panadería", "Panetteria", 250, 48.0, 10.0, 1.5, 4.0, 90, "g", "🥯", "" },
        { "Corn Tortillas", "Mais-Tortillas", "Tortillas de maïs", "Tortillas de maíz", "Tortillas di mais", "Bakery", "Bäckerei", "Boulangerie", "Panadería", "Panetteria", 218, 45.0, 5.7, 2.8, 6.0, 60, "g", "🌮", "" },

        // Proteins
        { "Chicken Breast (Grilled)", "Hähnchenbrust (gegrillt)", "Blanc de poulet (grillé)", "Pechuga de pollo (plancha)", "Petto di pollo (griglia)", "Poultry & Meat", "Fleisch & Geflügel", "Viandes", "Carnes", "Carne", 165, 0.0, 31.0, 3.6, 0.0, 150, "g", "🍗", "" },
        { "Lean Ground Beef (93/7)", "Mageres Rinderhack (93/7)", "Bœuf haché maigre", "Carne picada de ternera", "Carne macinata magra", "Poultry & Meat", "Fleisch & Geflügel", "Viandes", "Carnes", "Carne", 172, 0.0, 24.0, 8.0, 0.0, 150, "g", "🥩", "" },
        { "Atlantic Salmon (Baked)", "Lachsfilet (gebacken)", "Saumon atlantique (cuit)", "Salmón atlántico (horno)", "Salmone atlantico (forno)", "Fish & Seafood", "Fisch & Meeresfrüchte", "Poissons", "Pescados", "Pesce", 208, 0.0, 22.1, 12.3, 0.0, 140, "g", "🐟", "" },
        { "Tuna (Canned in Water)", "Thunfisch (im eigenen Saft)", "Thon au naturel (en boîte)", "Atún en agua", "Tonno al naturale", "Fish & Seafood", "Fisch & Meeresfrüchte", "Poissons", "Pescados", "Pesce", 116, 0.0, 26.0, 1.0, 0.0, 120, "g", "🐟", "" },
        { "Whole Egg (Large)", "Hühnerei (Größe L)", "Œuf entier (gros)", "Huevo entero (grande)", "Uovo intero (grande)", "Eggs & Dairy", "Eier & Milchprodukte", "Œufs & Produits laitiers", "Huevos y Lácteos", "Uova e Latticini", 143, 0.7, 12.6, 9.5, 0.0, 50, "g", "🍳", "" },
        { "Egg Whites", "Eiklar / Eiweiß", "Blancs d'œufs", "Claras de huevo", "Albume d'uovo", "Eggs & Dairy", "Eier & Milchprodukte", "Œufs & Produits laitiers", "Huevos y Lácteos", "Uova e Latticini", 52, 0.7, 10.9, 0.2, 0.0, 100, "g", "🥚", "" },
        { "Firm Tofu", "Naturtofu (fest)", "Tofu ferme", "Tofu firme", "Tofu compatto", "Plant Proteins", "Pflanzliche Proteine", "Protéines végétales", "Proteínas vegetales", "Proteine vegetali", 144, 2.8, 17.3, 8.7, 2.3, 150, "g", "🧈", "" },
        { "Tempeh", "Tempeh", "Tempeh", "Tempeh", "Tempeh", "Plant Proteins", "Pflanzliche Proteine", "Protéines végétales", "Proteínas vegetales", "Proteine vegetali", 192, 7.6, 20.3, 10.8, 0.0, 120, "g", "🌱", "" },
        { "Whey Protein Powder", "Whey Proteinpulver", "Poudre de Whey Protéine", "Proteína Whey en polvo", "Proteine Whey in polvere", "Supplements", "Nahrungsergänzung", "Compléments", "Suplementos", "Integratori", 390, 7.0, 78.0, 5.0, 1.0, 30, "g", "🥤", "" },
        { "Turkey Breast (Sliced)", "Putenbrust (Aufschnitt)", "Blanc de dinde (tranches)", "Pechuga de pavo (en lonchas)", "Petto di tacchino (fette)", "Poultry & Meat", "Fleisch & Geflügel", "Viandes", "Carnes", "Carne", 104, 1.5, 22.0, 1.0, 0.0, 100, "g", "🥪", "" },
        { "Shrimp (Cooked)", "Garnelen (gekocht)", "Crevettes (cuites)", "Gambas / Camarones (cocidos)", "Gamberetti (cotti)", "Fish & Seafood", "Fisch & Meeresfrüchte", "Poissons", "Pescados", "Pesce", 99, 0.2, 24.0, 0.3, 0.0, 120, "g", "🍤", "" },
        { "Greek Yogurt (Nonfat 0%)", "Griechischer Joghurt (0% Fett)", "Yaourt grec (0% matière grasse)", "Yogur griego (0% grasa)", "Yogurt greco (0% grassi)", "Eggs & Dairy", "Eier & Milchprodukte", "Œufs & Produits laitiers", "Huevos y Lácteos", "Uova e Latticini", 59, 3.6, 10.2, 0.4, 0.0, 170, "g", "🥛", "5201051001078" },
        { "Greek Yogurt (Whole 5%)", "Griechischer Joghurt (5% Fett)", "Yaourt grec entier (5%)", "Yogur griego entero (5%)", "Yogurt greco intero (5%)", "Eggs & Dairy", "Eier & Milchprodukte", "Œufs & Produits laitiers", "Huevos y Lácteos", "Uova e Latticini", 97, 4.0, 9.0, 5.0, 0.0, 150, "g", "🥛", "" },
        { "Cottage Cheese (Low Fat)", "Körniger Frischkäse (mager)", "Fromage blanc granuleux", "Queso cottage (bajo en grasa)", "Fiocchi di latte (magri)", "Eggs & Dairy", "Eier & Milchprodukte", "Œufs & Produits laitiers", "Huevos y Lácteos", "Uova e Latticini", 81, 4.7, 11.1, 2.3, 0.0, 150, "g", "🧀", "" },

        // Vegetables & Greens
        { "Baby Spinach", "Babyspinat", "Jeunes pousses d'épinard", "Espinacas baby", "Spinaci novelli", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 23, 3.6, 2.9, 0.4, 2.2, 80, "g", "🥬", "" },
        { "Broccoli Florets", "Brokkoli-Röschen", "Fleurettes de brocoli", "Floretes de brócoli", "Cime di broccoli", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 34, 6.6, 2.8, 0.4, 2.6, 120, "g", "🥦", "" },
        { "Carrots (Raw)", "Karotten (roh)", "Carottes (crues)", "Zanahorias (crudas)", "Carote (crude)", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 41, 9.6, 0.9, 0.2, 2.8, 100, "g", "🥕", "" },
        { "Red Bell Pepper", "Rote Paprika", "Poivron rouge", "Pimiento rojo", "Peperone rosso", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 31, 6.0, 1.0, 0.3, 2.1, 100, "g", "🫑", "" },
        { "Cucumber (with Peel)", "Salatgurke (mit Schale)", "Concombre (avec peau)", "Pepino (con piel)", "Cetriolo (con buccia)", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 15, 3.6, 0.7, 0.1, 0.5, 100, "g", "🥒", "" },
        { "Roma Tomatoes", "Roma-Tomaten", "Tomates Roma", "Tomates pera / Roma", "Pomodori Roma", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 18, 3.9, 0.9, 0.2, 1.2, 120, "g", "🍅", "" },
        { "Zucchini (Sliced)", "Zucchini (in Scheiben)", "Courgettes (en rondelles)", "Calabacín (en rodajas)", "Zucchine (a fette)", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 17, 3.1, 1.2, 0.3, 1.0, 120, "g", "🥒", "" },
        { "Button Mushrooms", "Champignons", "Champignons de Paris", "Champiñones", "Funghi champignon", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 22, 3.3, 3.1, 0.3, 1.0, 80, "g", "🍄", "" },
        { "Green Beans (Steamed)", "Grüne Bohnen (gedämpft)", "Haricots verts (vapeur)", "Judías verdes (vapor)", "Fagiolini (vapore)", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 35, 7.9, 1.9, 0.3, 3.2, 100, "g", "🫛", "" },
        { "Asparagus Spears", "Grüner Spargel", "Asperges vertes", "Espárragos verdes", "Asparagi verdi", "Vegetables", "Gemüse & Salate", "Légumes", "Verduras", "Verdure", 20, 3.9, 2.2, 0.1, 2.1, 100, "g", "🌱", "" },

        // Fruits & Berries
        { "Fresh Banana", "Frische Banane", "Banane fraîche", "Plátano fresco", "Banana fresca", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 89, 22.8, 1.1, 0.3, 2.6, 120, "g", "🍌", "" },
        { "Honeycrisp Apple", "Apfel (Honeycrisp)", "Pomme", "Manzana", "Mela", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 52, 13.8, 0.3, 0.2, 2.4, 150, "g", "🍎", "" },
        { "Fresh Blueberries", "Heidelbeeren (Blaubeeren)", "Myrtilles fraîches", "Arándanos frescos", "Mirtilli freschi", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 57, 14.5, 0.7, 0.3, 2.4, 100, "g", "🫐", "" },
        { "Fresh Strawberries", "Frische Erdbeeren", "Fraises fraîches", "Fresas frescas", "Fragole fresche", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 32, 7.7, 0.7, 0.3, 2.0, 120, "g", "🍓", "" },
        { "Fresh Raspberries", "Frische Himbeeren", "Framboises fraîches", "Frambuesas frescas", "Lamponi freschi", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 52, 11.9, 1.2, 0.7, 6.5, 80, "g", "🍇", "" },
        { "Orange", "Apfelsine / Orange", "Orange", "Naranja", "Arancia", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 47, 11.8, 0.9, 0.1, 2.4, 130, "g", "🍊", "" },
        { "Fresh Haas Avocado", "Frische Avocado (Haas)", "Avocat Haas frais", "Aguacate Haas fresco", "Avocado Haas fresco", "Healthy Fats", "Gesunde Fette", "Matières grasses", "Grasas saludables", "Grassi sani", 160, 8.5, 2.0, 14.7, 6.7, 80, "g", "🥑", "" },
        { "Kiwi Fruit", "Kiwi", "Kiwi", "Kiwi", "Kiwi", "Fruits", "Früchte & Beeren", "Fruits", "Frutas", "Frutta", 61, 14.7, 1.1, 0.5, 3.0, 75, "g", "🥝", "" },

        // Legumes & Beans
        { "Black Beans (Cooked)", "Schwarze Bohnen (gekocht)", "Haricots noirs (cuits)", "Frijoles negros (cocidos)", "Fagioli neri (cotti)", "Legumes", "Hülsenfrüchte", "Légumineuses", "Legumbres", "Legumi", 132, 23.7, 8.9, 0.5, 8.7, 130, "g", "🫘", "" },
        { "Chickpeas / Garbanzo (Cooked)", "Kichererbsen (gekocht)", "Pois chiches (cuits)", "Garbanzos (cocidos)", "Ceci (cotti)", "Legumes", "Hülsenfrüchte", "Légumineuses", "Legumbres", "Legumi", 164, 27.4, 8.9, 2.6, 7.6, 130, "g", "🧆", "" },
        { "Green Lentils (Cooked)", "Grüne Linsen (gekocht)", "Lentilles vertes (cuites)", "Lentejas verdes (cocidas)", "Lenticchie verdi (cotte)", "Legumes", "Hülsenfrüchte", "Légumineuses", "Legumbres", "Legumi", 116, 20.1, 9.0, 0.4, 7.9, 140, "g", "🍲", "" },
        { "Edamame (Shelled, Steamed)", "Edamame (geschält, gedämpft)", "Edamame (vapeur)", "Edamame (al vapor)", "Edamame (al vapore)", "Legumes", "Hülsenfrüchte", "Légumineuses", "Legumbres", "Legumi", 121, 8.9, 11.9, 5.2, 5.2, 100, "g", "🫛", "" },

        // Healthy Fats, Nuts & Seeds
        { "Raw Almonds", "Mandeln (roh)", "Amandes crues", "Almendras crudas", "Mandorle crude", "Nuts & Seeds", "Nüsse & Samen", "Fruits à coque", "Frutos secos", "Frutta a guscio", 579, 21.6, 21.2, 49.9, 12.5, 30, "g", "🥜", "" },
        { "English Walnuts", "Walnüsse", "Noix de Grenoble", "Nueces", "Noci", "Nuts & Seeds", "Nüsse & Samen", "Fruits à coque", "Frutos secos", "Frutta a guscio", 654, 13.7, 15.2, 65.2, 6.7, 30, "g", "🌰", "" },
        { "Natural Peanut Butter", "Erdnussbutter (100% pur)", "Beurre de cacahuète pur", "Crema de cacahuete pura", "Burro di arachidi puro", "Nuts & Seeds", "Nüsse & Samen", "Fruits à coque", "Frutos secos", "Frutta a guscio", 588, 20.0, 25.0, 50.0, 6.0, 32, "g", "🥜", "0051500241776" },
        { "Extra Virgin Olive Oil", "Natives Olivenöl Extra", "Huile d'olive vierge extra", "Aceite de oliva virgen extra", "Olio extravergine d'oliva", "Oils & Dressings", "Öle & Dressings", "Huiles", "Aceites", "Oli", 884, 0.0, 0.0, 100.0, 0.0, 15, "ml", "🫒", "" },
        { "Virgin Coconut Oil", "Kokosöl nativ", "Huile de coco vierge", "Aceite de coco virgen", "Olio di cocco vergine", "Oils & Dressings", "Öle & Dressings", "Huiles", "Aceites", "Oli", 862, 0.0, 0.0, 100.0, 0.0, 15, "g", "🥥", "" },
        { "Grass-Fed Butter", "Weidebutter", "Beurre de pâturage", "Mantequilla de pasto", "Burro da pascolo", "Dairy & Fats", "Milchprodukte & Fette", "Produits laitiers", "Lácteos y Grasas", "Latticini e Grassi", 717, 0.1, 0.9, 81.1, 0.0, 14, "g", "🧈", "" },
        { "Chia Seeds", "Chiasamen", "Graines de chia", "Semillas de chía", "Semi di chia", "Nuts & Seeds", "Nüsse & Samen", "Graines", "Semillas", "Semi", 486, 42.1, 16.5, 30.7, 34.4, 15, "g", "🌱", "" },

        // Dairy & Cheeses
        { "Whole Milk (3.25%)", "Vollmilch (3,5%)", "Lait entier", "Leche entera", "Latte intero", "Dairy & Milk", "Milch & Molkerei", "Laits", "Lácteos", "Latti", 61, 4.8, 3.2, 3.3, 0.0, 240, "ml", "🥛", "" },
        { "Unsweetened Almond Milk", "Mandelmilch (ungesüßt)", "Lait d'amande sans sucre", "Bebida de almendras", "Latte di mandorla", "Plant Milk", "Pflanzliche Milch", "Boissons végétales", "Bebidas vegetales", "Bevande vegetali", 13, 0.3, 0.4, 1.1, 0.2, 240, "ml", "🥛", "" },
        { "Cheddar Cheese", "Cheddar-Käse", "Fromage Cheddar", "Queso Cheddar", "Formaggio Cheddar", "Cheese", "Käse", "Fromages", "Quesos", "Formaggi", 403, 1.3, 24.9, 33.1, 0.0, 30, "g", "🧀", "" },
        { "Grated Parmesan", "Parmesan (gerieben)", "Parmesan râpé", "Parmesano rallado", "Parmigiano grattugiato", "Cheese", "Käse", "Fromages", "Quesos", "Formaggi", 431, 4.1, 38.4, 28.6, 0.0, 15, "g", "🧀", "" },

        // Cozy Treats & Extras
        { "Dark Chocolate (85% Cocoa)", "Zartbitterschokolade (85% Kakao)", "Chocolat noir (85% cacao)", "Chocolate negro (85%)", "Cioccolato fondente (85%)", "Snacks & Treats", "Snacks & Süßes", "En-cas", "Snacks", "Snack", 585, 36.0, 8.0, 46.0, 11.0, 25, "g", "🍫", "7610400070776" },
        { "Pure Honey", "Echter Bienenhonig", "Miel pur", "Miel pura", "Miele puro", "Sweeteners", "Süßungsmittel", "Édulcorants", "Endulzantes", "Dolcificanti", 304, 82.4, 0.3, 0.0, 0.2, 20, "g", "🍯", "" },
        { "Black Coffee (Brewed)", "Schwarzer Kaffee", "Café noir (infusé)", "Café negro solo", "Caffè nero americano", "Beverages", "Getränke", "Boissons", "Bebidas", "Bevande", 2, 0.0, 0.3, 0.0, 0.0, 240, "ml", "☕", "" },
        { "Green Tea (Brewed)", "Grüner Tee", "Thé vert infusé", "Té verde caliente", "Tè verde infuso", "Beverages", "Getränke", "Boissons", "Bebidas", "Bevande", 1, 0.0, 0.2, 0.0, 0.0, 240, "ml", "🍵", "" }
    };

    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    db.transaction();
    QSqlQuery q(db);
    q.prepare(QStringLiteral(
        "INSERT INTO foods (name, name_de, name_fr, name_es, name_it, "
        "                   category, category_de, category_fr, category_es, category_it, "
        "                   calories, carbs, protein, fat, fiber, serving_size, serving_unit, icon, barcode) "
        "VALUES (:name, :name_de, :name_fr, :name_es, :name_it, "
        "        :category, :category_de, :category_fr, :category_es, :category_it, "
        "        :calories, :carbs, :protein, :fat, :fiber, :serving_size, :serving_unit, :icon, :barcode);"
    ));

    for (const auto &item : starter) {
        // If an item with this English name already exists, update its translations
        QSqlQuery checkQ(db);
        checkQ.prepare(QStringLiteral("SELECT id FROM foods WHERE name = :name;"));
        checkQ.bindValue(QStringLiteral(":name"), QString::fromUtf8(item.name));
        if (checkQ.exec() && checkQ.next()) {
            int existingId = checkQ.value(0).toInt();
            QSqlQuery upQ(db);
            upQ.prepare(QStringLiteral(
                "UPDATE foods SET "
                "name_de = :name_de, name_fr = :name_fr, name_es = :name_es, name_it = :name_it, "
                "category_de = :cat_de, category_fr = :cat_fr, category_es = :cat_es, category_it = :cat_it, "
                "barcode = CASE WHEN barcode IS NULL OR barcode = '' THEN :barcode ELSE barcode END "
                "WHERE id = :id;"
            ));
            upQ.bindValue(QStringLiteral(":name_de"), QString::fromUtf8(item.name_de));
            upQ.bindValue(QStringLiteral(":name_fr"), QString::fromUtf8(item.name_fr));
            upQ.bindValue(QStringLiteral(":name_es"), QString::fromUtf8(item.name_es));
            upQ.bindValue(QStringLiteral(":name_it"), QString::fromUtf8(item.name_it));
            upQ.bindValue(QStringLiteral(":cat_de"), QString::fromUtf8(item.cat_de));
            upQ.bindValue(QStringLiteral(":cat_fr"), QString::fromUtf8(item.cat_fr));
            upQ.bindValue(QStringLiteral(":cat_es"), QString::fromUtf8(item.cat_es));
            upQ.bindValue(QStringLiteral(":cat_it"), QString::fromUtf8(item.cat_it));
            upQ.bindValue(QStringLiteral(":barcode"), QString::fromUtf8(item.barcode));
            upQ.bindValue(QStringLiteral(":id"), existingId);
            upQ.exec();
            continue;
        }

        q.bindValue(QStringLiteral(":name"), QString::fromUtf8(item.name));
        q.bindValue(QStringLiteral(":name_de"), QString::fromUtf8(item.name_de));
        q.bindValue(QStringLiteral(":name_fr"), QString::fromUtf8(item.name_fr));
        q.bindValue(QStringLiteral(":name_es"), QString::fromUtf8(item.name_es));
        q.bindValue(QStringLiteral(":name_it"), QString::fromUtf8(item.name_it));
        q.bindValue(QStringLiteral(":category"), QString::fromUtf8(item.category));
        q.bindValue(QStringLiteral(":category_de"), QString::fromUtf8(item.cat_de));
        q.bindValue(QStringLiteral(":category_fr"), QString::fromUtf8(item.cat_fr));
        q.bindValue(QStringLiteral(":category_es"), QString::fromUtf8(item.cat_es));
        q.bindValue(QStringLiteral(":category_it"), QString::fromUtf8(item.cat_it));
        q.bindValue(QStringLiteral(":calories"), item.calories);
        q.bindValue(QStringLiteral(":carbs"), item.carbs);
        q.bindValue(QStringLiteral(":protein"), item.protein);
        q.bindValue(QStringLiteral(":fat"), item.fat);
        q.bindValue(QStringLiteral(":fiber"), item.fiber);
        q.bindValue(QStringLiteral(":serving_size"), item.serving);
        q.bindValue(QStringLiteral(":serving_unit"), QString::fromUtf8(item.unit));
        q.bindValue(QStringLiteral(":icon"), QString::fromUtf8(item.icon));
        q.bindValue(QStringLiteral(":barcode"), QString::fromUtf8(item.barcode));
        q.exec();
    }
    db.commit();
}
