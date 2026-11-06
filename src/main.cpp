#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <windows.h>
#include "mpvvideorenderer.h"
#include "embyclient.h"
#include "player.h"

namespace {
HANDLE suEmbyRunningMutex = nullptr;
}

int main(int argc, char **argv) {
    suEmbyRunningMutex = CreateMutexW(nullptr, FALSE, L"Local\\SuEmby.Running");
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
