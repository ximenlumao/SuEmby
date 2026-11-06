#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QJsonObject>
#include <functional>
class EmbyClient:public QObject{Q_OBJECT Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged) Q_PROPERTY(QString error READ error NOTIFY errorChanged) Q_PROPERTY(QString server READ server) Q_PROPERTY(QString userId READ userId)
public:using QObject::QObject;QVariantList items()const{return m_items;}QString error()const{return m_error;}QString server()const{return m_server;}QString userId()const{return m_uid;}Q_INVOKABLE void login(QString,QString,QString);Q_INVOKABLE void load(QString type="Movie");Q_INVOKABLE void search(QString);Q_INVOKABLE void play(QString);
signals:void itemsChanged();void errorChanged();void loggedIn();void playUrl(QString);
private:QNetworkAccessManager net;QString m_server,m_token,m_uid,m_error;QVariantList m_items;void get(QString,QVariantMap,std::function<void(QJsonObject)>);};