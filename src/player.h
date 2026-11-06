#pragma once
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QTimer>
#include <mpv/client.h>

class Player : public QObject {
    Q_OBJECT
    Q_PROPERTY(double position READ position NOTIFY changed)
    Q_PROPERTY(double duration READ duration NOTIFY changed)
    Q_PROPERTY(double volumeLevel READ volumeLevel NOTIFY changed)
    Q_PROPERTY(int rotation READ rotation NOTIFY changed)
    Q_PROPERTY(bool playing READ playing NOTIFY changed)
    Q_PROPERTY(bool paused READ paused NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY changed)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY changed)
public:
    explicit Player(QObject *p = nullptr);
    ~Player();
    double position() const { return m_position; }
    double duration() const { return m_duration; }
    double volumeLevel() const { return m_volume; }
    int rotation() const { return m_rotation; }
    bool playing() const { return m_playing; }
    bool paused() const { return m_paused; }
    QString error() const { return m_error; }
    QVariantList audioTracks() const { return m_audioTracks; }
    QVariantList subtitleTracks() const { return m_subtitleTracks; }
    mpv_handle *handle() const { return m; }
    Q_INVOKABLE void play(const QString &url);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void setVolume(double value);
    Q_INVOKABLE void rotateVideo();
    Q_INVOKABLE void setAudioTrack(int id);
    Q_INVOKABLE void setSubtitleTrack(int id);
signals:
    void changed();
private slots:
    void poll();
private:
    mpv_handle *m = nullptr;
    QTimer *timer = nullptr;
    double m_position = 0, m_duration = 0, m_volume = 100;
    int m_rotation = 0;
    bool m_playing = false, m_paused = false;
    QString m_error;
    QVariantList m_audioTracks, m_subtitleTracks;
};
