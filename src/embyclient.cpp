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
        if (m_homeRequested) requestHomeSections();
    });
}

void EmbyClient::loadHome() {
    m_homeRequested = true;
    requestHomeSections();
    loadItems({{"Recursive", "true"}, {"Filters", "IsNotFolder"},
               {"IncludeItemTypes", "Movie,Series,MusicVideo,Video"},
               {"SortBy", "DateCreated"}, {"SortOrder", "Descending"}});
}

void EmbyClient::requestHomeSections() {
    const int generation = ++m_homeGeneration;
    QVariantList sections;
    for (const auto &value : m_libraries) {
        const QVariantMap library = value.toMap();
        const QString type = library.value("type").toString();
        QString includeTypes;
        if (type == "movies") includeTypes = "Movie";
        else if (type == "tvshows") includeTypes = "Series";
        else if (type == "musicvideos") includeTypes = "MusicVideo";
        else if (type == "homevideos") includeTypes = "Video";
        else if (type == "mixed" || type.isEmpty()) includeTypes = "Movie,Series,MusicVideo,Video";
        else continue;
        sections << QVariantMap{{"id", library.value("id")}, {"name", library.value("name")},
                                {"type", type}, {"items", QVariantList{}}};
    }
    m_homeSections = sections;
    emit homeSectionsChanged();

    for (int index = 0; index < sections.size(); ++index) {
        const QVariantMap section = sections.at(index).toMap();
        QVariantMap params{{"ParentId", section.value("id")}, {"Recursive", "true"},
                           {"Filters", "IsNotFolder"}, {"IncludeItemTypes", includeTypes},
                           {"SortBy", "DateCreated"}, {"SortOrder", "Descending"},
                           {"StartIndex", 0}, {"Limit", 12},
                           {"Fields", "Overview,UserData,Genres,DateCreated"},
                           {"ImageTypeLimit", 1}};
        if (section.value("type").toString() == "mixed") {
            params.remove("IncludeItemTypes");
            params.insert("ExcludeItemTypes", "Episode,Season");
        }
        QUrl url(m_server + "/emby/Users/" + m_uid + "/Items");
        QUrlQuery query;
        for (auto i = params.cbegin(); i != params.cend(); ++i)
            query.addQueryItem(i.key(), i.value().toString());
        url.setQuery(query);
        QNetworkRequest request(url);
        request.setRawHeader("X-Emby-Token", m_token.toUtf8());
        auto *reply = net.get(request);
        connect(reply, &QNetworkReply::finished, this, [this, reply, generation, index] {
            const QByteArray body = reply->readAll();
            const auto error = reply->error();
            const QString errorText = reply->errorString();
            reply->deleteLater();
            if (generation != m_homeGeneration) return;
            if (error != QNetworkReply::NoError) {
                m_error = errorText;
                emit errorChanged();
                return;
            }
            const QJsonArray values = QJsonDocument::fromJson(body).object().value("Items").toArray();
            QVariantList items;
            for (const auto &value : values) items << mapItem(value.toObject());
            if (index < 0 || index >= m_homeSections.size()) return;
            QVariantMap updated = m_homeSections.at(index).toMap();
            updated.insert("items", items);
            m_homeSections[index] = updated;
            emit homeSectionsChanged();
        });
    }
}

void EmbyClient::loadSeriesEpisodes(QString seriesId) {
    loadItems({{"__Endpoint", "SeriesEpisodes"}, {"__SeriesId", seriesId},
               {"UserId", m_uid}, {"Recursive", "true"}, {"IncludeItemTypes", "Episode"},
               {"SortBy", "ParentIndexNumber,IndexNumber"}, {"SortOrder", "Ascending"}});
}

void EmbyClient::load(QString type) {
    if (type == "Movie" || type == "Series") {
        loadItems({{"IncludeItemTypes", type}, {"Recursive", "true"}});
        return;
    }
    loadLibrary(type);
}

void EmbyClient::loadLibrary(QString id, QString collectionType) {
    QVariantMap params{{"ParentId", id}, {"Recursive", "true"}, {"Filters", "IsNotFolder"}};
    if (collectionType == "movies")
        params.insert("IncludeItemTypes", "Movie");
    else if (collectionType == "tvshows")
        params.insert("IncludeItemTypes", "Series");
    else if (collectionType == "musicvideos")
        params.insert("IncludeItemTypes", "MusicVideo");
    else if (collectionType == "homevideos")
        params.insert("IncludeItemTypes", "Video");
    else if (collectionType == "photos")
        params.insert("IncludeItemTypes", "Photo");
    else if (collectionType == "books")
        params.insert("IncludeItemTypes", "Book");
    else if (collectionType == "mixed")
        params.insert("ExcludeItemTypes", "Episode,Season");
    loadItems(params);
}

void EmbyClient::loadSpecial(QString mode) {
    if (mode == "resume") {
        loadItems({{"__Endpoint", "Resume"}, {"Recursive", "true"},
                   {"SortBy", "DatePlayed"}, {"Filters", "IsResumable"},
                   {"IncludeItemTypes", "Movie,Episode"}});
    } else if (mode == "favorites") {
        loadItems({{"Recursive", "true"}, {"SortBy", "DateCreated"},
                   {"Filters", "IsFavorite"}, {"IncludeItemTypes", "Movie,Series"}});
    }
}

void EmbyClient::loadMore() {
    if (m_loading || !hasMore()) return;
    loadItems(m_currentQuery, true);
}

QVariantMap EmbyClient::mapItem(const QJsonObject &x) const {
    const QString id = x.value("Id").toString();
    const auto tags = x.value("ImageTags").toObject();
    const auto backdrops = x.value("BackdropImageTags").toArray();
    const QString token = "?X-Emby-Token=" + QString::fromLatin1(QUrl::toPercentEncoding(m_token));
    return QVariantMap{
        {"id", id}, {"name", x.value("Name").toString()}, {"type", x.value("Type").toString()},
        {"overview", x.value("Overview").toString()},
        {"year", x.value("ProductionYear").toInt()},
        {"seasonNumber", x.value("ParentIndexNumber").toInt()},
        {"episodeNumber", x.value("IndexNumber").toInt()},
        {"rating", x.value("CommunityRating").toDouble()},
        {"favorite", x.value("UserData").toObject().value("IsFavorite").toBool()},
        {"image", m_server + "/emby/Items/" + id + "/Images/Primary" + token},
        {"backdrop", backdrops.isEmpty() ? QString() :
            m_server + "/emby/Items/" + id + "/Images/Backdrop/0" + token},
        {"hasBackdrop", !backdrops.isEmpty()},
        {"genres", x.value("Genres").toArray().toVariantList()},
        {"hasPoster", tags.contains("Primary")}
    };
}

void EmbyClient::loadItems(QVariantMap params, bool append) {
    if (append) {
        params = m_currentQuery;
    } else {
        m_currentQuery = params;
        m_nextStart = 0;
        m_total = 0;
        emit hasMoreChanged();
    }
    const QString endpoint = params.take("__Endpoint").toString();
    const QString seriesId = params.take("__SeriesId").toString();
    const int startIndex = append ? m_nextStart : 0;
    params.insert("StartIndex", startIndex);
    params.insert("SortBy", params.value("SortBy", "DateCreated"));
    params.insert("SortOrder", params.value("SortOrder",
        endpoint == "SeriesEpisodes" ? "Ascending" : "Descending"));
    params.insert("Fields", "Overview,UserData,Genres");
    params.insert("ImageTypeLimit", "1");
    params.insert("Limit", "48");
    const int generation = ++m_itemsGeneration;
    m_loading = true;
    emit loadingChanged();
    QString path = "/emby/Users/" + m_uid + "/Items" +
                   (endpoint == "Resume" ? "/Resume" : "");
    if (endpoint == "SeriesEpisodes")
        path = "/emby/Shows/" + seriesId + "/Episodes";
    const bool allowEpisodes = endpoint == "Resume" || endpoint == "SeriesEpisodes";
    get(path, params, [this, generation, startIndex, append, allowEpisodes](QJsonObject o) {
        if (generation != m_itemsGeneration) return;
        m_loading = false;
        emit loadingChanged();
        if (!append) m_items.clear();
        m_total = o.value("TotalRecordCount").toInt();
        m_nextStart = startIndex;
        for (const auto &v : o.value("Items").toArray()) {
            const auto x = v.toObject();
            const QString mediaType = x.value("Type").toString();
            if (mediaType == "Season" || (mediaType == "Episode" && !allowEpisodes)) continue;
            m_items << mapItem(x);
        }
        m_nextStart = startIndex + o.value("Items").toArray().size();
        emit itemsChanged();
        emit hasMoreChanged();
    });
}

void EmbyClient::search(QString s) {
    loadItems({{"SearchTerm", s}, {"Recursive", "true"},
               {"IncludeItemTypes", "Movie,Series"}});
}

void EmbyClient::post(QString path, QJsonObject body) {
    QNetworkRequest request(QUrl(m_server + path));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("X-Emby-Token", m_token.toUtf8());
    auto *reply = net.post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (reply->error() != QNetworkReply::NoError) {
            m_error = reply->errorString();
            emit errorChanged();
        }
        reply->deleteLater();
    });
}

void EmbyClient::setFavorite(QString id, bool favorite) {
    const QString path = "/emby/Users/" + m_uid + "/FavoriteItems/" + id +
                         (favorite ? "" : "/Delete");
    QNetworkRequest request(QUrl(m_server + path));
    request.setRawHeader("X-Emby-Token", m_token.toUtf8());
    auto *reply = net.post(request, QByteArray{});
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto error = reply->error();
        const QString errorText = reply->errorString();
        reply->deleteLater();
        if (error != QNetworkReply::NoError) {
            m_error = errorText;
            emit errorChanged();
        } else if (!m_currentQuery.isEmpty()) {
            loadItems(m_currentQuery);
        }
    });
}

void EmbyClient::reportPlaybackProgress(double position, double duration,
                                        QString eventName, bool isPaused) {
    Q_UNUSED(duration);
    if (m_playbackItemId.isEmpty()) return;
    const qint64 ticks = static_cast<qint64>(qMax(0.0, position) * 10000000.0);
    const QJsonObject body{
        {"QueueableMediaTypes", QJsonArray{"Video"}},
        {"CanSeek", true}, {"ItemId", m_playbackItemId},
        {"MediaSourceId", m_mediaSourceId}, {"IsPaused", isPaused},
        {"IsMuted", false}, {"PositionTicks", ticks}, {"VolumeLevel", 100},
        {"PlayMethod", "DirectPlay"}, {"PlaySessionId", m_playSessionId},
        {"PlaylistIndex", 0}, {"PlaylistLength", 1}, {"PlaybackRate", 1.0},
        {"EventName", eventName}
    };
    post("/emby/Sessions/Playing/Progress", body);
}

void EmbyClient::stopPlayback(double position, double duration) {
    if (m_playbackItemId.isEmpty()) return;
    const qint64 ticks = static_cast<qint64>(qMax(0.0, position) * 10000000.0);
    const QJsonObject body{
        {"QueueableMediaTypes", QJsonArray{"Video"}},
        {"CanSeek", true}, {"ItemId", m_playbackItemId},
        {"MediaSourceId", m_mediaSourceId}, {"IsPaused", false},
        {"IsMuted", false}, {"PositionTicks", ticks}, {"VolumeLevel", 100},
        {"PlayMethod", "DirectPlay"}, {"PlaySessionId", m_playSessionId},
        {"PlaylistIndex", 0}, {"PlaylistLength", 1}, {"PlaybackRate", 1.0}
    };
    post("/emby/Sessions/Playing/Stopped", body);
    if (duration > 0 && position / duration >= 0.9)
        post("/emby/Users/" + m_uid + "/PlayedItems/" + m_playbackItemId);
    m_playbackItemId.clear();
    m_mediaSourceId.clear();
    m_playSessionId.clear();
}

void EmbyClient::play(QString id) {
    m_error.clear();
    emit errorChanged();
    get("/emby/Items/" + id + "/PlaybackInfo", {{"UserId", m_uid}}, [this, id](QJsonObject o) {
        const auto sources = o.value("MediaSources").toArray();
        if (sources.isEmpty()) {
            m_error = "Emby 没有返回可播放的视频源。请确认该影片有可播放文件，或尝试稍后重试。";
            emit errorChanged();
            return;
        }
        const auto source = sources.first().toObject();
        m_playbackItemId = id;
        m_mediaSourceId = source.value("Id").toString();
        m_playSessionId = o.value("PlaySessionId").toString();
        if (m_playSessionId.isEmpty())
            m_playSessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        const QJsonObject started{
            {"QueueableMediaTypes", QJsonArray{"Video"}},
            {"CanSeek", true}, {"ItemId", id}, {"MediaSourceId", m_mediaSourceId},
            {"IsPaused", false}, {"IsMuted", false}, {"PositionTicks", 0},
            {"VolumeLevel", 100}, {"PlayMethod", "DirectPlay"},
            {"PlaySessionId", m_playSessionId}, {"PlaylistIndex", 0},
            {"PlaylistLength", 1}, {"PlaybackRate", 1.0}
        };
        post("/emby/Sessions/Playing", started);
        const QString url = m_server + "/emby/Videos/" + id +
            "/stream?static=true&mediaSourceId=" + QString::fromLatin1(QUrl::toPercentEncoding(m_mediaSourceId)) +
            "&PlaySessionId=" + QString::fromLatin1(QUrl::toPercentEncoding(m_playSessionId)) +
            "&X-Emby-Token=" + QString::fromLatin1(QUrl::toPercentEncoding(m_token));
        emit playUrl(url);
    });
}
