#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "embyclient.h"
#include "player.h"
int main(int argc,char**argv){QGuiApplication app(argc,argv);qmlRegisterType<Player>("SuEmby",1,0,"Player");EmbyClient emby;QQmlApplicationEngine e;e.rootContext()->setContextProperty("emby",&emby);e.load(QUrl("qrc:/qml/Main.qml"));if(e.rootObjects().isEmpty())return 1;return app.exec();}
