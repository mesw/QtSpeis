#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QSettings>
#include <QTranslator>
#include <qqmlintegration.h>

class LanguageManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString currentLanguage READ currentLanguage WRITE setCurrentLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString currentLanguageName READ currentLanguageName NOTIFY languageChanged)
    Q_PROPERTY(QString currentLanguageFlag READ currentLanguageFlag NOTIFY languageChanged)
    Q_PROPERTY(bool showAllLanguages READ showAllLanguages WRITE setShowAllLanguages NOTIFY showAllLanguagesChanged)
    Q_PROPERTY(QVariantList availableLanguages READ availableLanguages NOTIFY showAllLanguagesChanged)

public:
    explicit LanguageManager(QObject *parent = nullptr);
    ~LanguageManager() override = default;

    static LanguageManager *instance() { return s_instance; }

    QString currentLanguage() const { return m_currentLanguage; }
    Q_INVOKABLE void setCurrentLanguage(const QString &langCode);

    bool showAllLanguages() const { return m_showAllLanguages; }
    void setShowAllLanguages(bool show);

    QString currentLanguageName() const;
    QString currentLanguageFlag() const;
    QVariantList availableLanguages() const;

    // Translation lookup: queries QTranslator via QCoreApplication::translate("QtSpeis", key),
    // with automatic fallback to English master dictionary
    Q_INVOKABLE QString t(const QString &key, const QVariantList &args = QVariantList()) const;
    Q_INVOKABLE QString trKey(const QString &key) const { return t(key); }

    // Restarts application (QProcess on desktop, page reload on WebAssembly)
    Q_INVOKABLE void restartApplication();

signals:
    void languageChanged(const QString &newLanguage);
    void showAllLanguagesChanged();

private:
    void initEnglishDictionary();
    void initGermanDictionary();

    static LanguageManager *s_instance;
    bool m_showAllLanguages = false;
    QString m_currentLanguage = QStringLiteral("en");
    QMap<QString, QString> m_enDict;
    QMap<QString, QString> m_deDict;
    QTranslator m_translator;
};
