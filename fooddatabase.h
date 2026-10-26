#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QSqlDatabase>
#include <qqmlintegration.h>

class FoodDatabase : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int totalCount READ totalCount NOTIFY databaseChanged)
    Q_PROPERTY(QString databasePath READ databasePath NOTIFY databaseChanged)
    Q_PROPERTY(QString currentLanguage READ currentLanguage WRITE setCurrentLanguage NOTIFY languageChanged)

public:
    explicit FoodDatabase(QObject *parent = nullptr);
    ~FoodDatabase() override;

    int totalCount() const;
    QString databasePath() const { return m_dbPath; }
    QString currentLanguage() const { return m_currentLanguage; }
    void setCurrentLanguage(const QString &lang);

    Q_INVOKABLE bool initDatabase(const QString &customPath = QString());
    Q_INVOKABLE bool loadExternalDatabase(const QString &filePath);
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 12, const QString &langOverride = QString());
    Q_INVOKABLE QVariantList exploreFoods(const QString &searchQuery = QString(),
                                          const QString &categoryFilter = QString(),
                                          const QString &sortBy = QStringLiteral("name"),
                                          bool sortAscending = true,
                                          int limit = 150,
                                          const QString &langOverride = QString());
    Q_INVOKABLE QStringList allCategories(const QString &langOverride = QString()) const;
    Q_INVOKABLE QVariantMap getFoodById(int id, const QString &langOverride = QString());
    Q_INVOKABLE QVariantMap getFoodByBarcode(const QString &barcode, const QString &langOverride = QString());
    Q_INVOKABLE QVariantMap findFoodByName(const QString &name, const QString &langOverride = QString());
    Q_INVOKABLE bool addFood(const QVariantMap &food);

    static QString localizeCategory(const QString &rawCat, const QString &lang);
    static QString mapToDbCategory(const QString &filter);

    // Static helper to locate or unpack speis.db on any platform (Desktop or WebAssembly)
    static QString resolveSpeisDbPath(const QString &customPath = QString());

signals:
    void databaseChanged();
    void languageChanged(const QString &newLanguage);
    void errorOccurred(const QString &error);

private:
    void populateStarterCatalog();
    QString m_connectionName;
    QString m_dbPath;
    QString m_currentLanguage = QStringLiteral("en");
    bool m_initialized = false;
};
