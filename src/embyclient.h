#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QJsonObject>
#include <functional>

class EmbyClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(QVariantList libraries READ libraries NOTIFY librariesChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString server READ server)
    Q_PROPERTY(QString userId READ userId)
    Q_PROPERTY(QString savedServer READ savedServer CONSTANT)
    Q_PROPERTY(QString savedUsername READ savedUsername CONSTANT)
    Q_PROPERTY(QString savedPassword READ savedPassword CONSTANT)
public:
    using QObject::QObject;
    QVariantList items() const { return m_items; }
    QVariantList libraries() const { return m_libraries; }
    QString error() const { return m_error; }
    QString server() const { return m_server; }
    QString userId() const { return m_uid; }
    QString savedServer() const;
    QString savedUsername() const;
    QString savedPassword() const;
    Q_INVOKABLE void restoreSession();
    Q_INVOKABLE void login(QString, QString, QString);
    Q_INVOKABLE void refreshLibraries();
    Q_INVOKABLE void load(QString type = "Movie");
    Q_INVOKABLE void loadLibrary(QString id, QString collectionType = QString());
    Q_INVOKABLE void search(QString);
    Q_INVOKABLE void play(QString);
signals:
    void itemsChanged();
    void librariesChanged();
    void errorChanged();
    void loggedIn();
    void playUrl(QString);
private:
    QNetworkAccessManager net;
    QString m_server, m_token, m_uid, m_error;
    QVariantList m_items, m_libraries;
    int m_itemsGeneration = 0;
    void get(QString, QVariantMap, std::function<void(QJsonObject)>);
    void authenticate(QString server, QString username, QString password);
    void loadItems(QVariantMap params);
};
