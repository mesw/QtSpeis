#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <qqmlintegration.h>

class MealPlanManager;
class GameLevelManager;
class LanguageManager;

class SavegameManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool hasSavedGame READ hasSavedGame NOTIFY savegameChanged)
    Q_PROPERTY(QString lastSavedTime READ lastSavedTime NOTIFY savegameChanged)
    Q_PROPERTY(QString savegameSummary READ savegameSummary NOTIFY savegameChanged)
    Q_PROPERTY(QVariantList saveSlots READ saveSlots NOTIFY saveSlotsChanged)
    Q_PROPERTY(int slotCount READ slotCount NOTIFY saveSlotsChanged)

public:
    explicit SavegameManager(QObject *parent = nullptr);

    bool hasSavedGame() const;
    QString lastSavedTime() const { return m_lastSavedTime; }
    QString savegameSummary() const { return m_savegameSummary; }
    QVariantList saveSlots() const { return m_saveSlots; }
    int slotCount() const { return m_saveSlots.size(); }

    // Named Savegame Slots (In-memory & local persistent storage, no file upload/download required)
    Q_INVOKABLE bool saveToSlot(const QString &slotName, QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang = QString());
    Q_INVOKABLE bool loadFromSlot(const QString &slotId, QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj);
    Q_INVOKABLE bool overwriteSlot(const QString &slotId, QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang = QString());
    Q_INVOKABLE bool deleteSlot(const QString &slotId);
    Q_INVOKABLE bool renameSlot(const QString &slotId, const QString &newName);
    Q_INVOKABLE QString getSlotJson(const QString &slotId) const;
    Q_INVOKABLE void exportSlotToFile(const QString &slotId);

    // Auto-save to browser localStorage (WASM) or QSettings (Desktop)
    Q_INVOKABLE bool autoSave(QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang = QString());

    // Auto-load on application start
    Q_INVOKABLE bool autoLoad(QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj);

    // Export savegame to JSON string
    Q_INVOKABLE QString exportSavegameJson(QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang = QString()) const;

    // Import savegame from JSON string
    Q_INVOKABLE bool importSavegameJson(const QString &jsonStr, QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj);

    // Import from local file path or URL
    Q_INVOKABLE bool importFromFilePath(const QString &filePathOrUrl, QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj);

    // Trigger file download (.json)
    Q_INVOKABLE void exportToFile(QObject *mealPlanObj, QObject *gameLevelObj, const QString &lang = QString());

    // Trigger file picker to load .json file
    Q_INVOKABLE void requestImportFromFile(QObject *mealPlanObj, QObject *gameLevelObj, QObject *langManagerObj);

    // Clear saved game (resets browser storage)
    Q_INVOKABLE void clearSavedGame();

    // Raw clipboard helper
    Q_INVOKABLE void copyToClipboard(const QString &text);

    // C++ callback when HTML file input on WebAssembly reads text
    static void onWasmFileImported(const QString &jsonText);

signals:
    void savegameChanged();
    void savegameSaved();
    void savegameLoaded();
    void saveSlotsChanged();
    void importFailed(const QString &errorMsg);
    void fileImportReady(const QString &jsonText);
    void filePickerRequested();

private:
    QString getStoredSavegame() const;
    void setStoredSavegame(const QString &jsonStr);
    void updateSummaryFromStored();

    QString getStoredSlots() const;
    void setStoredSlots(const QString &jsonStr);
    void loadSlotsFromStored();
    void exportJsonStringToFilename(const QString &jsonStr, const QString &filename);

    QString m_lastSavedTime;
    QString m_savegameSummary;
    QVariantList m_saveSlots;
    static SavegameManager *s_instance;
    QObject *m_pendingMealPlan = nullptr;
    QObject *m_pendingGameLevel = nullptr;
    QObject *m_pendingLangManager = nullptr;
};
