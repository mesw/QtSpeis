#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFontDatabase>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QTranslator>
#include <QSettings>
#include <cstdio>

#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)
#include <emscripten.h>
#endif

static void customLogHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    Q_UNUSED(type); Q_UNUSED(context);
    fprintf(stderr, "%s\n", qPrintable(msg));
    fflush(stderr);
    QFile f(QStringLiteral("speis_debug.log"));
    if (f.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&f);
        out << msg << "\n";
    }
}

int main(int argc, char *argv[])
{
    qInstallMessageHandler(customLogHandler);
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

#if defined(HAS_EMOJI_FONT) && (defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__))
    const int fontId = QFontDatabase::addApplicationFont(
        QStringLiteral(":/fonts/NotoColorEmoji.ttf"));
    if (fontId == -1) {
        qWarning("Failed to load NotoColorEmoji.ttf from resources");
    } else {
        const QStringList families = QFontDatabase::applicationFontFamilies(fontId);
        for (const QString &fam : families) {
            QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Common, fam);
            QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Latin, fam);
            QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Greek, fam);
            QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Cyrillic, fam);
            QFontDatabase::addApplicationFallbackFontFamily(QChar::Script_Han, fam);
        }
        qInfo() << "Loaded emoji font from resources, id:" << fontId << "families:" << families;
    }
#endif

    QSettings settings;
    QString appLang = settings.value(QStringLiteral("appLanguage"), QStringLiteral("en")).toString().trimmed().toLower();
#if defined(QTSPEIS_WASM) || defined(__EMSCRIPTEN__)
    char *wasmSavedLang = (char*)EM_ASM_PTR({
        try {
            var l = localStorage.getItem('appLanguage');
            if (!l) return 0;
            var len = lengthBytesUTF8(l) + 1;
            var p = _malloc(len);
            stringToUTF8(l, p, len);
            return p;
        } catch(e) { return 0; }
    });
    if (wasmSavedLang) {
        QString s = QString::fromUtf8(wasmSavedLang).trimmed().toLower();
        free(wasmSavedLang);
        if (s == QStringLiteral("de") || s == QStringLiteral("en")) {
            appLang = s;
        }
    }
#endif
    QTranslator translator;
    if (appLang == QStringLiteral("de")) {
        if (translator.load(QStringLiteral(":/translations/qtspeis_de.qm")) ||
            translator.load(QStringLiteral("translations/qtspeis_de.qm"))) {
            app.installTranslator(&translator);
            qInfo() << "Installed German QTranslator from qtspeis_de.qm";
        } else {
            qWarning() << "Failed to load qtspeis_de.qm from resources or local directory";
        }
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError> &warnings) {
        for (const auto &w : warnings) {
            qCritical() << "QML ERROR:" << w.toString();
        }
    });
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [](const QUrl &url) { 
            qCritical() << "Failed to load root QML object:" << url;
            QCoreApplication::exit(-1); 
        },
        Qt::QueuedConnection);
    engine.loadFromModule("QtSpeis", "Main");

    return app.exec();
}
