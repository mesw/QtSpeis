#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

#ifdef HAS_EMOJI_FONT
    const int fontId = QFontDatabase::addApplicationFont(
        QStringLiteral(":/fonts/NotoColorEmoji.ttf"));
    if (fontId == -1)
        qWarning("Failed to load NotoColorEmoji.ttf from resources");
    else
        qInfo() << "Loaded emoji font from resources, id:" << fontId;
#endif

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
