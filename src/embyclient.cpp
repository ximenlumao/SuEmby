#include "embyclient.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrlQuery>
#include <QNetworkReply>
#include <QSettings>
#include <QByteArray>
#include <windows.h>
#include <dpapi.h>
#include <QUuid>

namespace {
QString protectPassword(const QString &password) {
    const QByteArray bytes = password.toUtf8();
    DATA_BLOB input{static_cast<DWORD>(bytes.size()), reinterpret_cast<BYTE *>(const_cast<char *>(bytes.constData()))};
    DATA_BLOB output{};
    if (!CryptProtectData(&input, L"SuEmby saved login", nullptr, nullptr, nullptr,
                          0, &output)) return {};
    const QByteArray encoded(reinterpret_cast<const char *>(output.pbData), static_cast<int>(output.cbData));
    LocalFree(output.pbData);
    return QString::fromLatin1(encoded.toBase64());
}
QString unprotectPassword(const QString &value) {
    const QByteArray encoded = QByteArray::fromBase64(value.toLatin1());
    DATA_BLOB input{static_cast<DWORD>(encoded.size()), reinterpret_cast<BYTE *>(const_cast<char *>(encoded.constData()))};
    DATA_BLOB output{};
    if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, 0, &output)) return {};
    const QByteArray plain(reinterpret_cast<const char *>(output.pbData), static_cast<int>(output.cbData));
    LocalFree(output.pbData);
    return QString::fromUtf8(plain);
}
}

QString EmbyClient::savedServer() const { QSettings s; return s.value("account/server").toString(); }
QString EmbyClient::savedUsername() const { QSettings s; return s.value("account/username").toString(); }
QString EmbyClient::savedPassword() const { QSettings s; return unprotectPassword(s.value("account/password").toString()); }

void EmbyClient::restoreSession() {
    const QString server = savedServer();
    const QString username = savedUsername();
    const QString password = savedPassword();
    if (!server.isEmpty() && !username.isEmpty() && !password.isEmpty())
        authenticate(server, username, password);
}

void EmbyClient::login(QString server, QString username, QString password) {
    authenticate(server, username, password);
}

void EmbyClient::authenticate(QString server, QString username, QString password) {
    m_server = server.trimmed();
    while (m_server.endsWith('/')) m_server.chop(1);
    if (!m_server.startsWith("http://") && !m_server.startsWith("https://"))
        m_server.prepend("http://");
    QNetworkRequest r(QUrl(m_server + "/emby/Users/AuthenticateByName"));
    r.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    r.setRawHeader("X-Emby-Authorization",
                   "MediaBrowser Client=SuEmby, Device=Windows, DeviceId=suemby, Version=0.3");
    auto *p = net.post(r, QJsonDocument(QJsonObject{{"Username", username}, {"Pw", password}}).toJson());
    connect(p, &QNetworkReply::finished, this, [this, p, username, password] {
        const auto o = QJsonDocument::fromJson(p->readAll()).object();
        const QString token = o.value("AccessToken").toString();
        const QString uid = o.value("User").toObject().value("Id").toString();
        const QString networkError = p->errorString();
        p->deleteLater();
        if (token.isEmpty() || uid.isEmpty()) {
            m_error = "登录失败，请检查服务器地址、网络和账号密码。" +
                      (networkError.isEmpty() ? QString() : " " + networkError);
            emit errorChanged();
            return;
        }
        m_token = token;
        m_uid = uid;
        emit sessionChanged();
        QSettings settings;
        settings.setValue("account/server", m_server);
        settings.setValue("account/username", username);
        const QString encrypted = protectPassword(password);
        if (!encrypted.isEmpty()) settings.setValue("account/password", encrypted);
        settings.sync();
        m_error.clear();
        emit errorChanged();
        emit loggedIn();
        refreshLibraries();
    });
}

void EmbyClient::get(QString path, QVariantMap params, std::function<void(QJsonObject)> cb) {
    QUrl u(m_server + path);
    QUrlQuery q;
    for (auto i = params.begin(); i != params.end(); ++i)
        q.addQueryItem(i.key(), i.value().toString());
    u.setQuery(q);
    QNetworkRequest r(u);
    r.setRawHeader("X-Emby-Token", m_token.toUtf8());
    auto *p = net.get(r);
    connect(p, &QNetworkReply::finished, this, [this, p, cb] {
        const auto b = p->readAll();
        const auto error = p->error();
        const QString errorText = p->errorString();
        p->deleteLater();
        if (error != QNetworkReply::NoError) {
            m_error = errorText;
            if (m_loading) { m_loading = false; emit loadingChanged(); }
            emit errorChanged();
        } else {
            cb(QJsonDocument::fromJson(b).object());
        }
    });
}

void EmbyClient::refreshLibraries() {
    if (m_uid.isEmpty()) return;
    get("/emby/Users/" + m_uid + "/Views", {{"IncludeHidden", "false"}}, [this](QJsonObject o) {
        m_libraries.clear();
        for (const auto &value : o.value("Items").toArray()) {
            const auto item = value.toObject();
            const QString type = item.value("CollectionType").toString();
            if (item.value("Id").toString().isEmpty()) continue;
            if (type.isEmpty() || type == "movies" || type == "tvshows" || type == "musicvideos" ||
                type == "homevideos" || type == "photos" || type == "mixed" || type == "books") {
                m_libraries << QVariantMap{
                    {"id", item.value("Id").toString()},
                    {"name", item.value("Name").toString()},
                    {"type", type}
                };
            }
        }
        emit librariesChanged();
        if (!m_libraries.isEmpty()) {
            const auto first = m_libraries.first().toMap();
            loadLibrary(first.value("id").toString(), first.value("type").toString());
        }
    });
}

void EmbyClient::load(QString type) {
    if (type == "Movie" || type == "Series") {
        loadItems({{"IncludeItemTypes", type}, {"Recursive", "true"}});
        return;
    }
    loadLibrary(type);
}

void EmbyClient::loadLibrary(QString id, QString collectionType) {
    QVariantMap params{{"ParentId", id}, {"Recursive", "true"}};
    if (collectionType == "movies")
        params.insert("IncludeItemTypes", "Movie");
    else if (collectionType == "tvshows")
        params.insert("IncludeItemTypes", "Series");
    else
        params.insert("IncludeItemTypes", "Movie,Series");
    loadItems(params);
}

void EmbyClient::loadItems(QVariantMap params) {
    params.insert("SortBy", "DateCreated");
    params.insert("SortOrder", "Descending");
    params.insert("Fields", "Overview,UserData,Genres");
    params.insert("ImageTypeLimit", "1");
    params.insert("Limit", "48");
    const int generation = ++m_itemsGeneration;
    m_loading = true;
    emit loadingChanged();
    get("/emby/Users/" + m_uid + "/Items", params, [this, generation](QJsonObject o) {
        if (generation != m_itemsGeneration) return;
        m_loading = false;
        emit loadingChanged();
        m_items.clear();
        for (const auto &v : o.value("Items").toArray()) {
            const auto x = v.toObject();
            const QString mediaType = x.value("Type").toString();
            if (mediaType == "Episode" || mediaType == "Season") continue;
            const QString id = x.value("Id").toString();
            const auto tags = x.value("ImageTags").toObject();
            const auto backdrops = x.value("BackdropImageTags").toArray();
            const QString token = "?X-Emby-Token=" + QString::fromLatin1(QUrl::toPercentEncoding(m_token));
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
                {"genres", x.value("Genres").toArray().toVariantList()},
                {"hasPoster", tags.contains("Primary")}
            };
            m_items << item;
        }
        emit itemsChanged();
    });
}

void EmbyClient::search(QString s) {
    loadItems({{"SearchTerm", s}, {"Recursive", "true"}, {"IncludeItemTypes", "Movie,Series"}});
}

void EmbyClient::play(QString id) {
    get("/emby/Items/" + id + "/PlaybackInfo", {}, [this, id](QJsonObject o) {
        const auto sources = o.value("MediaSources").toArray();
        if (sources.isEmpty()) {
            m_error = "服务器没有返回可播放的视频源";
            emit errorChanged();
            return;
        }
        const QString sourceId = sources.first().toObject().value("Id").toString();
        emit playUrl(m_server + "/emby/Videos/" + id +
                     "/stream?static=true&mediaSourceId=" + sourceId +
                     "&X-Emby-Token=" + QString::fromLatin1(QUrl::toPercentEncoding(m_token)));
    });
}
