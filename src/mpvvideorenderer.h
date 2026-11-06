#pragma once
#include <QQuickFramebufferObject>
#include <QPointer>
#include <QTimer>
#include "player.h"

class MpvVideoRenderer;

class MpvVideoItem : public QQuickFramebufferObject {
    Q_OBJECT
    Q_PROPERTY(Player *player READ player WRITE setPlayer NOTIFY playerChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
public:
    explicit MpvVideoItem(QQuickItem *parent = nullptr);
    Player *player() const { return m_player; }
    bool active() const { return m_active; }
    void setPlayer(Player *player);
    void setActive(bool active);
    Renderer *createRenderer() const override;
signals:
    void playerChanged();
    void activeChanged();
private:
    QPointer<Player> m_player;
    bool m_active = false;
    QTimer *m_frameTimer = nullptr;
};
