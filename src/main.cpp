#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include "mpvvideorenderer.h"
#include "embyclient.h"
#include "player.h"

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    QCoreApplication::setOrganizationName("SuEmby");
    QCoreApplication::setApplicationName("SuEmby");
    qmlRegisterType<Player>("SuEmby", 1, 0, "Player");
    qmlRegisterType<MpvVideoItem>("SuEmby", 1, 0, "MpvVideoItem");
    EmbyClient emby;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("emby", &emby);
    engine.load(QUrl("qrc:/qml/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
