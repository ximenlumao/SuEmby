#include "player.h"
#include <QTimer>
#include <QVariantMap>
#include <mpv/render.h>

namespace {
const mpv_node *mapValue(const mpv_node_list *list, const char *key) {
    if (!list || !key) return nullptr;
    for (int i = 0; i < list->num; ++i)
        if (list->keys[i] && qstrcmp(list->keys[i], key) == 0)
            return &list->values[i];
    return nullptr;
}

QString nodeText(const mpv_node *node) {
    return node && node->format == MPV_FORMAT_STRING && node->u.string
        ? QString::fromUtf8(node->u.string) : QString();
}
}
Player::Player(QObject *parent) : QObject(parent) {
    m = mpv_create();
    if (!m) return;
    mpv_set_option_string(m, "vo", "libmpv");
    mpv_set_option_string(m, "gpu-api", "opengl");
    mpv_set_option_string(m, "hwdec", "auto-copy");
    mpv_set_option_string(m, "video-rotate", "0");
    mpv_set_option_string(m, "keep-open", "no");
    mpv_initialize(m);
    timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &Player::poll);
    timer->start(500);
}

Player::~Player() {
    if (m) mpv_terminate_destroy(m);
}

void Player::play(const QString &url) {
    if (!m) return;
    m_rotation = 0;
    int64_t rotation = 0;
    mpv_set_property(m, "video-rotate", MPV_FORMAT_INT64, &rotation);
    const QByteArray encoded = url.toUtf8();
    const char *args[] = {"loadfile", encoded.constData(), nullptr};
    m_error.clear();
    const int status = mpv_command_async(m, 0, args);
    m_playing = status >= 0;
    m_paused = false;
    m_position = 0;
    m_duration = 0;
    if (status < 0) m_error = QString::fromUtf8(mpv_error_string(status));
    emit changed();
}

void Player::stop() {
    if (!m) return;
    const char *args[] = {"stop", nullptr};
    mpv_command_async(m, 0, args);
    m_position = 0;
    m_duration = 0;
    m_playing = false;
    m_paused = false;
    m_error.clear();
    emit changed();
}

void Player::setAudioTrack(int id) {
    if (!m) return;
    int64_t track = id;
    mpv_set_property(m, "aid", MPV_FORMAT_INT64, &track);
}

void Player::setSubtitleTrack(int id) {
    if (!m) return;
    int64_t track = id;
    mpv_set_property(m, "sid", MPV_FORMAT_INT64, &track);
}

void Player::pause() {
    if (!m) return;
    int paused = 0;
    if (mpv_get_property(m, "pause", MPV_FORMAT_FLAG, &paused) >= 0) {
        paused = !paused;
        mpv_set_property(m, "pause", MPV_FORMAT_FLAG, &paused);
        m_paused = paused != 0;
        emit changed();
    }
}

void Player::seek(double seconds) {
    if (!m || seconds < 0) return;
    const QByteArray position = QByteArray::number(seconds, 'f', 3);
    const char *args[] = {"seek", position.constData(), "absolute+exact", nullptr};
    mpv_command_async(m, 0, args);
}

void Player::setVolume(double value) {
    if (!m) return;
    const double bounded = qBound(0.0, value, 100.0);
    double actual = bounded;
    const int status = mpv_set_property(m, "volume", MPV_FORMAT_DOUBLE, &actual);
    if (status < 0) {
        m_error = QString::fromUtf8(mpv_error_string(status));
    } else {
        m_volume = bounded;
        m_error.clear();
    }
    emit changed();
}

void Player::rotateVideo() {
    if (!m) return;
    m_rotation = (m_rotation + 90) % 360;
    int64_t degrees = m_rotation;
    const int status = mpv_set_property(m, "video-rotate", MPV_FORMAT_INT64, &degrees);
    if (status < 0) m_error = QString::fromUtf8(mpv_error_string(status));
    else m_error.clear();
    emit changed();
}

void Player::poll() {
    if (!m) return;
    while (true) {
        const mpv_event *event = mpv_wait_event(m, 0);
        if (!event || event->event_id == MPV_EVENT_NONE) break;
        if (event->event_id == MPV_EVENT_END_FILE && event->data) {
            const auto *end = static_cast<const mpv_event_end_file *>(event->data);
            if (end->reason == MPV_END_FILE_REASON_ERROR) {
                m_error = QString::fromUtf8(mpv_error_string(end->error));
                m_playing = false;
                m_paused = false;
            } else if (end->reason == MPV_END_FILE_REASON_EOF) {
                m_playing = false;
                m_paused = false;
            }
        }
    }
    double position = 0;
    double duration = 0;
    double volume = 100;
    if (mpv_get_property(m, "time-pos", MPV_FORMAT_DOUBLE, &position) >= 0)
        m_position = position;
    if (mpv_get_property(m, "duration", MPV_FORMAT_DOUBLE, &duration) >= 0)
        m_duration = duration;
    if (mpv_get_property(m, "volume", MPV_FORMAT_DOUBLE, &volume) >= 0)
        m_volume = qBound(0.0, volume, 100.0);

    mpv_node tracks{};
    if (mpv_get_property(m, "track-list", MPV_FORMAT_NODE, &tracks) >= 0 &&
        tracks.format == MPV_FORMAT_NODE_ARRAY && tracks.u.list) {
        QVariantList audio;
        QVariantList subtitles;
        subtitles << QVariantMap{{"id", -1}, {"label", "关闭字幕"}, {"selected", false}};
        for (int i = 0; i < tracks.u.list->num; ++i) {
            const mpv_node &entry = tracks.u.list->values[i];
            if (entry.format != MPV_FORMAT_NODE_MAP || !entry.u.list) continue;
            const QString type = nodeText(mapValue(entry.u.list, "type"));
            const mpv_node *idNode = mapValue(entry.u.list, "id");
            const mpv_node *titleNode = mapValue(entry.u.list, "title");
            const mpv_node *langNode = mapValue(entry.u.list, "lang");
            const mpv_node *selectedNode = mapValue(entry.u.list, "selected");
            if (!idNode || idNode->format != MPV_FORMAT_INT64) continue;
            const int id = static_cast<int>(idNode->u.int64);
            QString label = nodeText(titleNode);
            const QString language = nodeText(langNode);
            if (label.isEmpty()) label = language.isEmpty() ? QString("轨道 %1").arg(id) : language;
            else if (!language.isEmpty()) label += " · " + language;
            const bool selected = selectedNode && selectedNode->format == MPV_FORMAT_FLAG &&
                                  selectedNode->u.flag != 0;
            const QVariantMap item{{"id", id}, {"label", label}, {"selected", selected}};
            if (type == "audio") audio << item;
            else if (type == "sub") subtitles << item;
        }
        m_audioTracks = audio;
        m_subtitleTracks = subtitles;
        mpv_free_node_contents(&tracks);
    }
    emit changed();
}
