#include "player.h"
#include <QTimer>

Player::Player(QObject *parent) : QObject(parent) {
    m = mpv_create();
    if (!m) return;
    mpv_set_option_string(m, "vo", "libmpv");
    mpv_set_option_string(m, "gpu-api", "opengl");
    mpv_set_option_string(m, "hwdec", "auto-safe");
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
    const QByteArray encoded = url.toUtf8();
    const char *args[] = {"loadfile", encoded.constData(), nullptr};
    mpv_command_async(m, 0, args);
    m_playing = true;
    m_paused = false;
    m_position = 0;
    m_duration = 0;
    m_playing = false;
    m_paused = false;
    emit changed();
}

void Player::stop() {
    if (!m) return;
    const char *args[] = {"stop", nullptr};
    mpv_command_async(m, 0, args);
    m_position = 0;
    m_duration = 0;
    emit changed();
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
    if (!m) return;
    mpv_set_property(m, "time-pos", MPV_FORMAT_DOUBLE, &seconds);
}

void Player::volume(double value) {
    if (!m) return;
    mpv_set_property(m, "volume", MPV_FORMAT_DOUBLE, &value);
}

void Player::poll() {
    if (!m) return;
    mpv_get_property(m, "time-pos", MPV_FORMAT_DOUBLE, &m_position);
    mpv_get_property(m, "duration", MPV_FORMAT_DOUBLE, &m_duration);
    emit changed();
}
