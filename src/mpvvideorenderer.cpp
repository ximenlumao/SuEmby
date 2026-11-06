#include "mpvvideorenderer.h"
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFramebufferObjectFormat>
#include <QOpenGLFunctions>
#include <QQuickOpenGLUtils>
#include <QByteArray>
#include <mpv/render.h>
#include <mpv/render_gl.h>

namespace {
void *getMpvGlProc(void *, const char *name) {
    auto *context = QOpenGLContext::currentContext();
    return context ? reinterpret_cast<void *>(context->getProcAddress(QByteArray(name))) : nullptr;
}

class MpvRenderer final : public QQuickFramebufferObject::Renderer {
public:
    ~MpvRenderer() override {
        if (m_renderContext) mpv_render_context_free(m_renderContext);
    }

    void synchronize(QQuickFramebufferObject *item) override {
        auto *video = static_cast<MpvVideoItem *>(item);
        m_handle = video->player() ? video->player()->handle() : nullptr;
        m_active = video->active();
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override {
        QOpenGLFramebufferObjectFormat format;
        format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
        format.setTextureTarget(GL_TEXTURE_2D);
        format.setInternalTextureFormat(GL_RGBA8);
        return new QOpenGLFramebufferObject(size, format);
    }

    void render() override {
        auto *context = QOpenGLContext::currentContext();
        if (!context || !m_active || !m_handle) return;
        if (!m_renderContext || m_contextHandle != m_handle) {
            if (m_renderContext) {
                mpv_render_context_free(m_renderContext);
                m_renderContext = nullptr;
            }
            mpv_opengl_init_params glInit{getMpvGlProc, nullptr};
            mpv_render_param initParams[] = {
                {MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
                {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInit},
                {MPV_RENDER_PARAM_INVALID, nullptr}
            };
            if (mpv_render_context_create(&m_renderContext, m_handle, initParams) < 0) {
                m_renderContext = nullptr;
                return;
            }
            m_contextHandle = m_handle;
        }

        const QSize size = framebufferObject()->size();
        mpv_opengl_fbo fbo{static_cast<int>(framebufferObject()->handle()),
                           size.width(), size.height(), GL_RGBA8};
        int flipY = 1;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
            {MPV_RENDER_PARAM_FLIP_Y, &flipY},
            {MPV_RENDER_PARAM_INVALID, nullptr}
        };
        mpv_render_context_render(m_renderContext, params);
        context->functions()->glFlush();
        QQuickOpenGLUtils::resetOpenGLState();
    }

private:
    mpv_handle *m_handle = nullptr;
    mpv_handle *m_contextHandle = nullptr;
    mpv_render_context *m_renderContext = nullptr;
    bool m_active = false;
};
}

MpvVideoItem::MpvVideoItem(QQuickItem *parent)
    : QQuickFramebufferObject(parent), m_frameTimer(new QTimer(this)) {
    setMirrorVertically(false);
    m_frameTimer->setInterval(33);
    connect(m_frameTimer, &QTimer::timeout, this, [this] { update(); });
}

void MpvVideoItem::setPlayer(Player *player) {
    if (m_player == player) return;
    m_player = player;
    emit playerChanged();
    update();
}

void MpvVideoItem::setActive(bool active) {
    if (m_active == active) return;
    m_active = active;
    if (m_active) m_frameTimer->start();
    else m_frameTimer->stop();
    emit activeChanged();
    update();
}

QQuickFramebufferObject::Renderer *MpvVideoItem::createRenderer() const {
    return new MpvRenderer;
}
