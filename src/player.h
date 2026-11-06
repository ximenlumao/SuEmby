#pragma once
#include <QObject>
#include <QString>
#include <QTimer>
#include <mpv/client.h>

class Player : public QObject {
    Q_OBJECT
    Q_PROPERTY(double position READ position NOTIFY changed)
    Q_PROPERTY(double duration READ duration NOTIFY changed)
public:
    explicit Player(QObject *p = nullptr);
    ~Player();
    double position() const { return m_position; }
    double duration() const { return m_duration; }
    Q_INVOKABLE void play(const QString &url);
    Q_INVOKABLE void pause();
    Q_INVOKABLE void seek(double seconds);
    Q_INVOKABLE void volume(double value);
signals:
    void changed();
private slots:
    void poll();
private:
    mpv_handle *m = nullptr;
    QTimer *timer = nullptr;
    double m_position = 0, m_duration = 0;
};
