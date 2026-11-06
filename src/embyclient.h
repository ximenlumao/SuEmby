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
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasMore READ hasMore NOTIFY hasMoreChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString server READ server NOTIFY sessionChanged)
    Q_PROPERTY(QString userId READ userId NOTIFY sessionChanged)
    Q_PROPERTY(QString savedServer READ savedServer CONSTANT)
    Q_PROPERTY(QString savedUsername READ savedUsername CONSTANT)
    Q_PROPERTY(QString savedPassword READ savedPassword CONSTANT)
public:
    using QObject::QObject;
    QVariantList items() const { return m_items; }
    QVariantList libraries() const { return m_libraries; }
    bool loading() const { return m_loading; }
    bool hasMore() const { return m_nextStart < m_total; }
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
    Q_INVOKABLE void loadHome();
    Q_INVOKABLE void loadLibrary(QString id, QString collectionType = QString());
    Q_INVOKABLE void search(QString);
    Q_INVOKABLE void loadSpecial(QString mode);
    Q_INVOKABLE void loadMore();
    Q_INVOKABLE void setFavorite(QString id, bool favorite);
    Q_INVOKABLE void reportPlaybackProgress(double position, double duration, QString eventName = "TimeUpdate", bool isPaused = false);
    Q_INVOKABLE void stopPlayback(double position, double duration);
    Q_INVOKABLE void play(QString);
signals:
    void itemsChanged();
    void librariesChanged();
    void loadingChanged();
    void hasMoreChanged();
    void sessionChanged();
    void errorChanged();
    void loggedIn();
    void playUrl(QString);
private:
    QNetworkAccessManager net;
    QString m_server, m_token, m_uid, m_error;
    QString m_playbackItemId, m_mediaSourceId, m_playSessionId;
    QVariantList m_items, m_libraries;
    QVariantMap m_currentQuery;
    int m_nextStart = 0;
    int m_total = 0;
    int m_itemsGeneration = 0;
    bool m_loading = false;
    void get(QString, QVariantMap, std::function<void(QJsonObject)>);
    void authenticate(QString server, QString username, QString password);
    void loadItems(QVariantMap params, bool append = false);
    void post(QString path, QJsonObject body = {});
};
