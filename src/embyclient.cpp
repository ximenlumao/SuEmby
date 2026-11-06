#include "embyclient.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrlQuery>
#include <QNetworkReply>

void EmbyClient::get(QString path, QVariantMap params, std::function<void(QJsonObject)> cb) {
    QUrl u(m_server + path);
    QUrlQuery q;
    for (auto i = params.begin(); i != params.end(); ++i)
        q.addQueryItem(i.key(), i.value().toString());
    u.setQuery(q);
    QNetworkRequest r(u);
    r.setRawHeader("X-Emby-Token", m_token.toUtf8());
    auto *p = net.get(r);
    connect(p, &QNetworkReply::finished, this, [=] {
        auto b = p->readAll();
        if (p->error() != QNetworkReply::NoError) {
            m_error = p->errorString();
            emit errorChanged();
        } else {
            cb(QJsonDocument::fromJson(b).object());
        }
        p->deleteLater();
    });
}

void EmbyClient::login(QString s, QString u, QString pw) {
    m_server = s.trimmed();
    while (m_server.endsWith('/')) m_server.chop(1);
    QNetworkRequest r(QUrl(m_server + "/emby/Users/AuthenticateByName"));
    r.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    r.setRawHeader("X-Emby-Authorization",
                   "MediaBrowser Client=SuEmby, Device=Windows, DeviceId=suemby, Version=0.2");
    auto *p = net.post(r, QJsonDocument(QJsonObject{{"Username", u}, {"Pw", pw}}).toJson());
    connect(p, &QNetworkReply::finished, this, [=] {
        auto o = QJsonDocument::fromJson(p->readAll()).object();
        m_token = o.value("AccessToken").toString();
        m_uid = o.value("User").toObject().value("Id").toString();
        p->deleteLater();
        if (m_token.isEmpty()) {
            m_error = "登录失败，请检查服务器地址和账号";
            emit errorChanged();
        } else {
            emit loggedIn();
        }
    });
}

void EmbyClient::load(QString type) {
    get("/emby/Users/" + m_uid + "/Items",
        {{"IncludeItemTypes", type}, {"Recursive", "true"},
         {"Fields", "Overview,People,UserData,Genres,MediaSources"},
         {"ImageTypeLimit", "1"}, {"Limit", "100"}},
        [=](QJsonObject o) {
            m_items.clear();
            for (const auto &v : o.value("Items").toArray()) {
                const auto x = v.toObject();
                const QString id = x.value("Id").toString();
                const auto tags = x.value("ImageTags").toObject();
                const auto backdrops = x.value("BackdropImageTags").toArray();
                const QString token = "?X-Emby-Token=" + m_token;
                QVariantMap item{
                    {"id", id},
                    {"name", x.value("Name").toString()},
                    {"overview", x.value("Overview").toString()},
                    {"year", x.value("ProductionYear").toInt()},
                    {"rating", x.value("CommunityRating").toDouble()},
                    {"favorite", x.value("UserData").toObject().value("IsFavorite").toBool()},
                    {"image", m_server + "/emby/Items/" + id + "/Images/Primary" + token},
                    {"backdrop", backdrops.isEmpty() ? QString() :
                        m_server + "/emby/Items/" + id + "/Images/Backdrop/0" + token},
                    {"hasBackdrop", !backdrops.isEmpty()},
                    {"genres", x.value("Genres").toArray().toVariantList()}
                };
                item["hasPoster"] = tags.contains("Primary");
                m_items << item;
            }
            emit itemsChanged();
        });
}

void EmbyClient::search(QString s) {
    get("/emby/Users/" + m_uid + "/Items",
        {{"SearchTerm", s}, {"Recursive", "true"},
         {"Fields", "Overview,UserData"}, {"Limit", "100"}},
        [=](QJsonObject o) {
            m_items.clear();
            for (const auto &v : o.value("Items").toArray()) {
                const auto x = v.toObject();
                const QString id = x.value("Id").toString();
                const QString token = "?X-Emby-Token=" + m_token;
                m_items << QVariantMap{
                    {"id", id}, {"name", x.value("Name").toString()},
                    {"overview", x.value("Overview").toString()},
                    {"image", m_server + "/emby/Items/" + id + "/Images/Primary" + token},
                    {"year", x.value("ProductionYear").toInt()}
                };
            }
            emit itemsChanged();
        });
}

void EmbyClient::play(QString id) {
    get("/emby/Items/" + id + "/PlaybackInfo", {}, [=](QJsonObject o) {
        const auto sources = o.value("MediaSources").toArray();
        if (sources.isEmpty()) {
            m_error = "服务器没有返回可播放的视频源";
            emit errorChanged();
            return;
        }
        const QString sourceId = sources.first().toObject().value("Id").toString();
        emit playUrl(m_server + "/emby/Videos/" + id +
                     "/stream?static=true&mediaSourceId=" + sourceId +
                     "&X-Emby-Token=" + m_token);
    });
}
