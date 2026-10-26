#include "savegamemanager.h"
#include "mealplanmanager.h"
#include "gamelevelmanager.h"
#include "languagemanager.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QSettings>
#include <QClipboard>
#include <QGuiApplication>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>
#include <QDesktopServices>
#include <QRegularExpression>
#include <QDebug>

#ifdef QTSPEIS_WASM
#include <emscripten.h>
#include <emscripten/val.h>

extern "C" {
EMSCRIPTEN_KEEPALIVE
void speis_receive_imported_file(const char *utf8Content) {
    if (utf8Content) {
        SavegameManager::onWasmFileImported(QString::fromUtf8(utf8Content));
    }
}
}
#endif

SavegameManager *SavegameManager::s_instance = nullptr;

SavegameManager::SavegameManager(QObject *parent)
    : QObject(parent)
{
    s_instance = this;
    updateSummaryFromStored();
    loadSlotsFromStored();

#ifdef QTSPEIS_WASM
    MAIN_THREAD_EM_ASM({
        window._speisReceiveImport = function(text) {
            if (typeof text !== "string") return;
            var lengthBytes = lengthBytesUTF8(text) + 1;
            var stringOnWasmHeap = _malloc(lengthBytes);
            stringToUTF8(text, stringOnWasmHeap, lengthBytes);
            _speis_receive_imported_file(stringOnWasmHeap);
            _free(stringOnWasmHeap);
        };
    });
#endif
}

void SavegameManager::onWasmFileImported(const QString &jsonText)
{
    if (s_instance) {
        emit s_instance->fileImportReady(jsonText);
        if (s_instance->m_pendingMealPlan && s_instance->m_pendingGameLevel) {
            s_instance->importSavegameJson(jsonText,
                                          s_instance->m_pendingMealPlan,
                                          s_instance->m_pendingGameLevel,
                                          s_instance->m_pendingLangManager);
        }
    }
}

QString SavegameManager::getStoredSavegame() const
{
#ifdef QTSPEIS_WASM
    using emscripten::val;
    val window = val::global("window");
    if (!window.isUndefined()) {
        val storage = window["localStorage"];
        if (!storage.isUndefined() && !storage.isNull()) {
            val item = storage.call<val>("getItem", std::string("speis_savegame_v1"));
            if (!item.isUndefined() && !item.isNull()) {
                return QString::fromUtf8(item.as<std::string>().c_str());
            }
        }
    }
    return QString();
#else
    QSettings settings(QStringLiteral("SpeisApp"), QStringLiteral("SaveGame"));
    return settings.value(QStringLiteral("speis_savegame_v1")).toString();
#endif
}

void SavegameManager::setStoredSavegame(const QString &jsonStr)
{
#ifdef QTSPEIS_WASM
    using emscripten::val;
    val window = val::global("window");
    if (!window.isUndefined()) {
        val storage = window["localStorage"];
        if (!storage.isUndefined() && !storage.isNull()) {
            if (jsonStr.isEmpty()) {
                storage.call<void>("removeItem", std::string("speis_savegame_v1"));
            } else {
                storage.call<void>("setItem", std::string("speis_savegame_v1"), std::string(jsonStr.toUtf8().constData()));
            }
        }
    }
#else
    QSettings settings(QStringLiteral("SpeisApp"), QStringLiteral("SaveGame"));
    if (jsonStr.isEmpty()) {
        settings.remove(QStringLiteral("speis_savegame_v1"));
    } else {
        settings.setValue(QStringLiteral("speis_savegame_v1"), jsonStr);
    }
    settings.sync();
#endif
    updateSummaryFromStored();
}

QString SavegameManager::getStoredSlots() const
{
#ifdef QTSPEIS_WASM
    using emscripten::val;
    val window = val::global("window");
    if (!window.isUndefined()) {
        val storage = window["localStorage"];
        if (!storage.isUndefined() && !storage.isNull()) {
            val item = storage.call<val>("getItem", std::string("speis_savegame_slots_v1"));
            if (!item.isUndefined() && !item.isNull()) {
                return QString::fromUtf8(item.as<std::string>().c_str());
            }
        }
    }
    return QString();
#else
    QSettings settings(QStringLiteral("SpeisApp"), QStringLiteral("SaveGame"));
    return settings.value(QStringLiteral("speis_savegame_slots_v1")).toString();
#endif
}

void SavegameManager::setStoredSlots(const QString &jsonStr)
{
#ifdef QTSPEIS_WASM
    using emscripten::val;
    val window = val::global("window");
    if (!window.isUndefined()) {
        val storage = window["localStorage"];
        if (!storage.isUndefined() && !storage.isNull()) {
            if (jsonStr.isEmpty()) {
                storage.call<void>("removeItem", std::string("speis_savegame_slots_v1"));
            } else {
                storage.call<void>("setItem", std::string("speis_savegame_slots_v1"), std::string(jsonStr.toUtf8().constData()));
            }
        }
    }
#else
    QSettings settings(QStringLiteral("SpeisApp"), QStringLiteral("SaveGame"));
    if (jsonStr.isEmpty()) {
        settings.remove(QStringLiteral("speis_savegame_slots_v1"));
    } else {
        settings.setValue(QStringLiteral("speis_savegame_slots_v1"), jsonStr);
    }
    settings.sync();
#endif
    loadSlotsFromStored();
}

void SavegameManager::loadSlotsFromStored()
{
    m_saveSlots.clear();
    QString stored = getStoredSlots();
    if (stored.trimmed().isEmpty()) {
        emit saveSlotsChanged();
        return;
    }

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(stored.toUtf8(), &err);
    if (err.error == QJsonParseError::NoError && doc.isArray()) {
        QJsonArray arr = doc.array();
        for (const QJsonValue &val : arr) {
            if (val.isObject()) {
                m_saveSlots.append(val.toObject().toVariantMap());
            }
        }
    }
    emit saveSlotsChanged();
}

void SavegameManager::updateSummaryFromStored()
{
    QString stored = getStoredSavegame();
    if (stored.isEmpty()) {
        m_lastSavedTime = QStringLiteral("Never");
        m_savegameSummary = QStringLiteral("No saved meal plan yet.");
        emit savegameChanged();
        return;
    }

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(stored.toUtf8(), &err);
    if (err.error == QJsonParseError::NoError && doc.isObject()) {
        QJsonObject root = doc.object();
        m_lastSavedTime = root.value(QStringLiteral("savedAt")).toString();
        int meals = root.value(QStringLiteral("mealCount")).toInt();
        int cal = root.value(QStringLiteral("totalCalories")).toInt();
        int lvl = root.value(QStringLiteral("currentLevel")).toInt(1);
        int tgt = root.value(QStringLiteral("targetCalories")).toInt(cal);
        QString uName;
        if (root.contains(QStringLiteral("userProfile"))) {
            uName = root.value(QStringLiteral("userProfile")).toObject().value(QStringLiteral("userName")).toString();
        }
        if (!uName.isEmpty()) {
            m_savegameSummary = QStringLiteral("%1 • Level %2 • %3 meals • %4 / %5 kcal")
                                    .arg(uName).arg(lvl).arg(meals).arg(cal).arg(tgt);
        } else {
            m_savegameSummary = QStringLiteral("Level %1 • %2 meals • %3 / %4 kcal").arg(lvl).arg(meals).arg(cal).arg(tgt);
        }
    } else {
        m_lastSavedTime = QStringLiteral("Unknown");
        m_savegameSummary = QStringLiteral("Saved plan found");
    }
    emit savegameChanged();
}

bool SavegameManager::hasSavedGame() const
{
    return !getStoredSavegame().trimmed().isEmpty();
}

QString SavegameManager::exportSavegameJson(QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang) const
{
    MealPlanManager *plan = qobject_cast<MealPlanManager*>(mealPlanObj);
    GameLevelManager *level = qobject_cast<GameLevelManager*>(gameLevelObj);
    if (!plan) return QString();

    QJsonObject root;
    root[QStringLiteral("app")] = QStringLiteral("Speis");
    root[QStringLiteral("version")] = QStringLiteral("1.0");
    root[QStringLiteral("savedAt")] = QDateTime::currentDateTime().toString(Qt::ISODate);
    root[QStringLiteral("mealCount")] = plan->mealCount();
    root[QStringLiteral("totalCalories")] = static_cast<int>(std::round(plan->totalCalories()));
    root[QStringLiteral("baseCalories")] = plan->baseCalories();
    root[QStringLiteral("targetCalories")] = plan->targetCalories();
    root[QStringLiteral("totalWorkoutCalories")] = plan->totalWorkoutCalories();
    root[QStringLiteral("totalCarbs")] = plan->totalCarbs();
    root[QStringLiteral("totalProtein")] = plan->totalProtein();
    root[QStringLiteral("totalFat")] = plan->totalFat();
    root[QStringLiteral("totalFiber")] = plan->totalFiber();

    QJsonObject profileObj;
    profileObj[QStringLiteral("userName")] = plan->userName();
    profileObj[QStringLiteral("baseCalories")] = plan->baseCalories();
    profileObj[QStringLiteral("userAge")] = plan->userAge();
    profileObj[QStringLiteral("userWeight")] = plan->userWeight();
    profileObj[QStringLiteral("userHeight")] = plan->userHeight();
    profileObj[QStringLiteral("userSex")] = plan->userSex();
    profileObj[QStringLiteral("userSport")] = plan->userSport();
    root[QStringLiteral("userProfile")] = profileObj;

    if (!lang.isEmpty()) {
        root[QStringLiteral("language")] = lang;
    }

    if (level) {
        root[QStringLiteral("currentLevel")] = level->currentLevel();
        QJsonObject starsObj;
        for (int l = 1; l <= level->allLevels().size(); ++l) {
            int st = level->getStars(l);
            if (st > 0) {
                starsObj[QStringLiteral("lvl_%1").arg(l)] = st;
            }
        }
        root[QStringLiteral("levelStars")] = starsObj;
    } else {
        root[QStringLiteral("currentLevel")] = 1;
    }

    QJsonArray mealsArr = QJsonArray::fromVariantList(plan->meals());
    root[QStringLiteral("meals")] = mealsArr;

    QJsonDocument doc(root);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

bool SavegameManager::autoSave(QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang)
{
    QString jsonStr = exportSavegameJson(mealPlanObj, gameLevelObj, lang);
    if (jsonStr.isEmpty()) return false;
    setStoredSavegame(jsonStr);
    emit savegameSaved();
    return true;
}

bool SavegameManager::importSavegameJson(const QString &jsonStr, QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj)
{
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        emit importFailed(QStringLiteral("Invalid JSON format."));
        return false;
    }

    QJsonObject root = doc.object();
    MealPlanManager *plan = qobject_cast<MealPlanManager*>(mealPlanObj);
    GameLevelManager *level = qobject_cast<GameLevelManager*>(gameLevelObj);
    LanguageManager *langMgr = qobject_cast<LanguageManager*>(langManagerObj);

    if (!plan) {
        emit importFailed(QStringLiteral("Meal plan manager not available."));
        return false;
    }

    // Restore language if present
    if (langMgr && root.contains(QStringLiteral("language"))) {
        QString l = root.value(QStringLiteral("language")).toString();
        if (!l.isEmpty()) {
            langMgr->setCurrentLanguage(l);
        }
    }

    // Restore level and stars if present
    if (level) {
        if (root.contains(QStringLiteral("currentLevel"))) {
            level->setCurrentLevel(root.value(QStringLiteral("currentLevel")).toInt(1));
        }
        if (root.contains(QStringLiteral("levelStars"))) {
            QJsonObject starsObj = root.value(QStringLiteral("levelStars")).toObject();
            for (auto it = starsObj.begin(); it != starsObj.end(); ++it) {
                QString k = it.key();
                if (k.startsWith(QStringLiteral("lvl_"))) {
                    int lvlId = k.mid(4).toInt();
                    int st = it.value().toInt();
                    if (lvlId > 0 && st > 0) {
                        level->saveStars(lvlId, st);
                    }
                }
            }
        }
    }

    // Restore user profile & base calories if present
    if (root.contains(QStringLiteral("userProfile"))) {
        QJsonObject p = root.value(QStringLiteral("userProfile")).toObject();
        QString uName = p.value(QStringLiteral("userName")).toString(QStringLiteral("Athlete"));
        double baseCal = p.value(QStringLiteral("baseCalories")).toDouble(2000.0);
        int age = p.value(QStringLiteral("userAge")).toInt(30);
        double w = p.value(QStringLiteral("userWeight")).toDouble(75.0);
        double h = p.value(QStringLiteral("userHeight")).toDouble(178.0);
        QString sex = p.value(QStringLiteral("userSex")).toString(QStringLiteral("male"));
        QString sport = p.value(QStringLiteral("userSport")).toString(QStringLiteral("endurance_power"));
        plan->setUserProfile(uName, baseCal, w, h, age, sex, sport);
    } else if (root.contains(QStringLiteral("baseCalories"))) {
        double baseCal = root.value(QStringLiteral("baseCalories")).toDouble(2000.0);
        plan->setBaseCalories(baseCal);
    }

    // Restore meals
    if (root.contains(QStringLiteral("meals")) && root.value(QStringLiteral("meals")).isArray()) {
        QVariantList mealsList = root.value(QStringLiteral("meals")).toArray().toVariantList();
        plan->setMeals(mealsList);
    }

    // Keep persistent storage up to date
    setStoredSavegame(jsonStr);
    emit savegameLoaded();
    return true;
}

bool SavegameManager::autoLoad(QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj)
{
    QString stored = getStoredSavegame();
    if (stored.trimmed().isEmpty()) return false;
    return importSavegameJson(stored, mealPlanObj, gameLevelObj, langManagerObj);
}

void SavegameManager::exportJsonStringToFilename(const QString &jsonStr, const QString &filename)
{
    if (jsonStr.isEmpty()) return;

#ifdef QTSPEIS_WASM
    using emscripten::val;
    val window = val::global("window");
    val document = val::global("document");
    if (!window.isUndefined() && !document.isUndefined()) {
        std::string contentStd = jsonStr.toStdString();
        val Blob = window["Blob"];
        val parts = val::array();
        parts.call<void>("push", val(contentStd));

        val opts = val::object();
        opts.set("type", "application/json");

        val blob = Blob.new_(parts, opts);
        val url = window["URL"].call<val>("createObjectURL", blob);

        val a = document.call<val>("createElement", std::string("a"));
        a.set("href", url);
        a.set("download", filename.toStdString());
        document["body"].call<void>("appendChild", a);
        a.call<void>("click");
        document["body"].call<void>("removeChild", a);
        window["URL"].call<void>("revokeObjectURL", url);
    }
#else
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty()) {
        dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    }
    QString path = dir + QStringLiteral("/") + filename;
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        f.write(jsonStr.toUtf8());
        f.close();
        QDesktopServices::openUrl(QUrl::fromLocalFile(dir));
    }
#endif
}

void SavegameManager::exportToFile(QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang)
{
    QString jsonStr = exportSavegameJson(mealPlanObj, gameLevelObj, lang);
    exportJsonStringToFilename(jsonStr, QStringLiteral("speis_mealplan.json"));
}

bool SavegameManager::saveToSlot(const QString &slotName, QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang)
{
    QString jsonStr = exportSavegameJson(mealPlanObj, gameLevelObj, lang);
    if (jsonStr.isEmpty()) return false;

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;

    MealPlanManager *plan = qobject_cast<MealPlanManager*>(mealPlanObj);
    GameLevelManager *level = qobject_cast<GameLevelManager*>(gameLevelObj);

    QString id = QStringLiteral("slot_%1").arg(QDateTime::currentMSecsSinceEpoch());
    QString name = slotName.trimmed();
    if (name.isEmpty()) {
        int lvl = level ? level->currentLevel() : 1;
        name = QStringLiteral("Level %1 Plan").arg(lvl);
    }

    int lvl = level ? level->currentLevel() : 1;
    int meals = plan ? plan->mealCount() : 0;
    int cal = plan ? static_cast<int>(std::round(plan->totalCalories())) : 0;
    int tgt = plan ? static_cast<int>(std::round(plan->targetCalories())) : 2000;
    QString uName = plan ? plan->userName() : QString();

    QVariantMap slotMap;
    slotMap[QStringLiteral("id")] = id;
    slotMap[QStringLiteral("name")] = name;
    slotMap[QStringLiteral("savedAt")] = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"));
    slotMap[QStringLiteral("level")] = lvl;
    slotMap[QStringLiteral("mealCount")] = meals;
    slotMap[QStringLiteral("totalCalories")] = cal;
    slotMap[QStringLiteral("targetCalories")] = tgt;
    slotMap[QStringLiteral("userName")] = uName;
    slotMap[QStringLiteral("summary")] = QStringLiteral("Level %1 • %2 meals • %3 / %4 kcal").arg(lvl).arg(meals).arg(cal).arg(tgt);
    slotMap[QStringLiteral("data")] = doc.object().toVariantMap();

    m_saveSlots.prepend(slotMap);

    QJsonArray arr;
    for (const QVariant &v : m_saveSlots) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    setStoredSlots(QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    emit saveSlotsChanged();
    return true;
}

bool SavegameManager::loadFromSlot(const QString &slotId, QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj)
{
    for (const QVariant &v : m_saveSlots) {
        QVariantMap map = v.toMap();
        if (map.value(QStringLiteral("id")).toString() == slotId) {
            QJsonObject dataObj = QJsonObject::fromVariantMap(map.value(QStringLiteral("data")).toMap());
            QJsonDocument doc(dataObj);
            QString jsonStr = QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
            bool ok = importSavegameJson(jsonStr, mealPlanObj, gameLevelObj, langManagerObj);
            if (ok) {
                autoSave(mealPlanObj, gameLevelObj);
            }
            return ok;
        }
    }
    emit importFailed(QStringLiteral("Save slot not found."));
    return false;
}

bool SavegameManager::overwriteSlot(const QString &slotId, QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang)
{
    QString jsonStr = exportSavegameJson(mealPlanObj, gameLevelObj, lang);
    if (jsonStr.isEmpty()) return false;

    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;

    MealPlanManager *plan = qobject_cast<MealPlanManager*>(mealPlanObj);
    GameLevelManager *level = qobject_cast<GameLevelManager*>(gameLevelObj);

    int idx = -1;
    for (int i = 0; i < m_saveSlots.size(); ++i) {
        if (m_saveSlots[i].toMap().value(QStringLiteral("id")).toString() == slotId) {
            idx = i;
            break;
        }
    }
    if (idx == -1) return false;

    QVariantMap slotMap = m_saveSlots[idx].toMap();
    int lvl = level ? level->currentLevel() : 1;
    int meals = plan ? plan->mealCount() : 0;
    int cal = plan ? static_cast<int>(std::round(plan->totalCalories())) : 0;
    int tgt = plan ? static_cast<int>(std::round(plan->targetCalories())) : 2000;
    QString uName = plan ? plan->userName() : QString();

    slotMap[QStringLiteral("savedAt")] = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"));
    slotMap[QStringLiteral("level")] = lvl;
    slotMap[QStringLiteral("mealCount")] = meals;
    slotMap[QStringLiteral("totalCalories")] = cal;
    slotMap[QStringLiteral("targetCalories")] = tgt;
    slotMap[QStringLiteral("userName")] = uName;
    slotMap[QStringLiteral("summary")] = QStringLiteral("Level %1 • %2 meals • %3 / %4 kcal").arg(lvl).arg(meals).arg(cal).arg(tgt);
    slotMap[QStringLiteral("data")] = doc.object().toVariantMap();

    m_saveSlots[idx] = slotMap;

    QJsonArray arr;
    for (const QVariant &v : m_saveSlots) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    setStoredSlots(QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    emit saveSlotsChanged();
    return true;
}

bool SavegameManager::deleteSlot(const QString &slotId)
{
    int idx = -1;
    for (int i = 0; i < m_saveSlots.size(); ++i) {
        if (m_saveSlots[i].toMap().value(QStringLiteral("id")).toString() == slotId) {
            idx = i;
            break;
        }
    }
    if (idx == -1) return false;

    m_saveSlots.removeAt(idx);

    QJsonArray arr;
    for (const QVariant &v : m_saveSlots) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    setStoredSlots(QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    emit saveSlotsChanged();
    return true;
}

bool SavegameManager::renameSlot(const QString &slotId, const QString &newName)
{
    QString n = newName.trimmed();
    if (n.isEmpty()) return false;

    int idx = -1;
    for (int i = 0; i < m_saveSlots.size(); ++i) {
        if (m_saveSlots[i].toMap().value(QStringLiteral("id")).toString() == slotId) {
            idx = i;
            break;
        }
    }
    if (idx == -1) return false;

    QVariantMap slotMap = m_saveSlots[idx].toMap();
    slotMap[QStringLiteral("name")] = n;
    m_saveSlots[idx] = slotMap;

    QJsonArray arr;
    for (const QVariant &v : m_saveSlots) {
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    }
    setStoredSlots(QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact)));
    emit saveSlotsChanged();
    return true;
}

QString SavegameManager::getSlotJson(const QString &slotId) const
{
    for (const QVariant &v : m_saveSlots) {
        QVariantMap map = v.toMap();
        if (map.value(QStringLiteral("id")).toString() == slotId) {
            QJsonObject dataObj = QJsonObject::fromVariantMap(map.value(QStringLiteral("data")).toMap());
            return QString::fromUtf8(QJsonDocument(dataObj).toJson(QJsonDocument::Indented));
        }
    }
    return QString();
}

void SavegameManager::exportSlotToFile(const QString &slotId)
{
    for (const QVariant &v : m_saveSlots) {
        QVariantMap map = v.toMap();
        if (map.value(QStringLiteral("id")).toString() == slotId) {
            QString name = map.value(QStringLiteral("name")).toString();
            QString sanitized = name;
            sanitized.replace(QRegularExpression(QStringLiteral("[^a-zA-Z0-9_-]")), QStringLiteral("_"));
            if (sanitized.isEmpty()) sanitized = QStringLiteral("save");
            QString filename = QStringLiteral("speis_%1.json").arg(sanitized);

            QJsonObject dataObj = QJsonObject::fromVariantMap(map.value(QStringLiteral("data")).toMap());
            QJsonDocument doc(dataObj);
            QString jsonStr = QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
            exportJsonStringToFilename(jsonStr, filename);
            return;
        }
    }
}

bool SavegameManager::importFromFilePath(const QString &filePathOrUrl, QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj)
{
    QString path = filePathOrUrl.trimmed();
    if (path.startsWith(QStringLiteral("file:///"))) {
        path = QUrl(path).toLocalFile();
    }
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit importFailed(QStringLiteral("Could not open file: %1").arg(path));
        return false;
    }
    QString content = QString::fromUtf8(f.readAll());
    f.close();
    return importSavegameJson(content, mealPlanObj, gameLevelObj, langManagerObj);
}

void SavegameManager::requestImportFromFile(QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj)
{
    m_pendingMealPlan = mealPlanObj;
    m_pendingGameLevel = gameLevelObj;
    m_pendingLangManager = langManagerObj;

#ifdef QTSPEIS_WASM
    MAIN_THREAD_EM_ASM({
        let input = document.getElementById('_speis_file_input');
        if (!input) {
            input = document.createElement('input');
            input.id = '_speis_file_input';
            input.type = 'file';
            input.accept = '.json,application/json';
            input.style.display = 'none';
            document.body.appendChild(input);
        }
        input.value = null;
        input.onchange = function(e) {
            let file = e.target.files[0];
            if (!file) return;
            let reader = new FileReader();
            reader.onload = function(evt) {
                let text = evt.target.result;
                if (window._speisReceiveImport) {
                    window._speisReceiveImport(text);
                }
            };
            reader.readAsText(file);
        };
        input.click();
    });
#else
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty()) {
        dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    }
    QString path = dir + QStringLiteral("/speis_mealplan.json");
    if (QFile::exists(path)) {
        importFromFilePath(path, mealPlanObj, gameLevelObj, langManagerObj);
    } else {
        emit importFailed(QStringLiteral("Place 'speis_mealplan.json' in your Downloads folder (%1), or paste the JSON text directly below.").arg(dir));
    }
#endif
}

void SavegameManager::clearSavedGame()
{
    setStoredSavegame(QString());
}

void SavegameManager::copyToClipboard(const QString &text)
{
    QClipboard *cb = QGuiApplication::clipboard();
    if (cb) {
        cb->setText(text);
    }
#ifdef QTSPEIS_WASM
    using emscripten::val;
    val navigator = val::global("navigator");
    if (!navigator.isUndefined()) {
        val clipboard = navigator["clipboard"];
        if (!clipboard.isUndefined()) {
            clipboard.call<void>("writeText", text.toStdString());
        }
    }
#endif
}
