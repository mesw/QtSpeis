#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

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
