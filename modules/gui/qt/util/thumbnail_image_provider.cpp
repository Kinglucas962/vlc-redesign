/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "thumbnail_image_provider.hpp"

#include <vlc_common.h>
#include <vlc_image.h>
#include <vlc_input_item.h>
#include <vlc_media_library.h>
#include <vlc_picture.h>
#include <vlc_preparser.h>

#include <QImage>
#include <QImageReader>
#include <QUrl>
#include <QUrlQuery>

namespace {

#define URL_KEY "url"
#define POSITION_KEY "pos"
#define ARTWORK_KEY "art"

// The MRL is base64 encoded: kept as is, its percent encoding included
constexpr auto mrlEncoding = QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals;

QString encodeMrl(const QString &mrl)
{
    return QString::fromLatin1(mrl.toUtf8().toBase64(mrlEncoding));
}

QString decodeMrl(const QString &value)
{
    const auto result = QByteArray::fromBase64Encoding(value.toLatin1(), mrlEncoding);
    return result ? QString::fromUtf8(*result) : QString();
}

// Frames are small: decoding them in software keeps the GPU for the video
constexpr int defaultWidth = 320;

QImage toImage(vlc_object_t *obj, picture_t *picture, const QSize &requestedSize)
{
    video_format_t fmtIn = picture->format;
    if (fmtIn.i_sar_num == 0 || fmtIn.i_sar_den == 0)
        fmtIn.i_sar_num = fmtIn.i_sar_den = 1;
    if (fmtIn.i_visible_width == 0 || fmtIn.i_visible_height == 0)
        return {};

    // Display size, then fit in the requested size
    QSize size(fmtIn.i_visible_width * fmtIn.i_sar_num / fmtIn.i_sar_den,
               fmtIn.i_visible_height);
    QSize bound(requestedSize.width() > 0 ? requestedSize.width() : defaultWidth,
                requestedSize.height() > 0 ? requestedSize.height() : INT_MAX);
    size.scale(bound, Qt::KeepAspectRatio);
    if (size.isEmpty())
        return {};

    video_format_t fmtOut;
    video_format_Init(&fmtOut, VLC_CODEC_RGBA);
    fmtOut.i_width = fmtOut.i_visible_width = size.width();
    fmtOut.i_height = fmtOut.i_visible_height = size.height();
    fmtOut.i_sar_num = fmtOut.i_sar_den = 1;

    image_handler_t *handler = image_HandlerCreate(obj);
    if (!handler)
        return {};
    picture_t *converted = image_Convert(handler, picture, &fmtIn, &fmtOut);
    image_HandlerDelete(handler);
    if (!converted)
        return {};

    QImage image = QImage(converted->p[0].p_pixels,
                          converted->format.i_visible_width,
                          converted->format.i_visible_height,
                          converted->p[0].i_pitch,
                          QImage::Format_RGBA8888).copy();
    picture_Release(converted);
    return image;
}

class ThumbnailResponse : public QQuickImageResponse
{
public:
    ThumbnailResponse(std::shared_ptr<vlc_preparser_t> preparser, vlc_object_t *obj,
                      const QString &mrl, double position, const QSize &requestedSize)
        : m_preparser(std::move(preparser))
        , m_state(std::make_shared<State>())
    {
        m_state->response = this;
        m_state->obj = obj;
        m_state->requestedSize = requestedSize;

        if (m_preparser)
            m_request = submit(mrl, position);
        if (!m_request)
        {
            m_state->error = QStringLiteral("Cannot generate a thumbnail of %1").arg(mrl);
            QMetaObject::invokeMethod(this, &QQuickImageResponse::finished, Qt::QueuedConnection);
        }
    }

    ~ThumbnailResponse() override
    {
        {
            std::lock_guard<std::recursive_mutex> guard(m_state->lock);
            m_state->response = nullptr;
        }
        if (m_request)
        {
            vlc_preparser_Cancel(m_preparser.get(), m_request);
            vlc_preparser_req_Release(m_request);
        }
    }

    QQuickTextureFactory *textureFactory() const override
    {
        std::lock_guard<std::recursive_mutex> guard(m_state->lock);
        return m_state->image.isNull() ? nullptr
                                       : QQuickTextureFactory::textureFactoryForImage(m_state->image);
    }

    QString errorString() const override
    {
        std::lock_guard<std::recursive_mutex> guard(m_state->lock);
        return m_state->error;
    }

    void cancel() override
    {
        // The end callback still runs, with no picture, and emits finished()
        if (m_request)
            vlc_preparser_Cancel(m_preparser.get(), m_request);
    }

private:
    // Shared with the end callback, which can outlive the response
    struct State
    {
        std::recursive_mutex lock;
        ThumbnailResponse *response = nullptr;
        vlc_object_t *obj = nullptr;
        QSize requestedSize;
        QImage image;
        QString error;
    };

    vlc_preparser_req *submit(const QString &mrl, double position)
    {
        input_item_t *item = input_item_New(qtu(mrl), nullptr);
        if (!item)
            return nullptr;

        struct vlc_thumbnailer_arg arg = {};
        arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_POS;
        arg.seek.pos = position;
        arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
        arg.hw_dec = false;

        static const struct vlc_thumbnailer_cbs cbs = { &ThumbnailResponse::onEnded };
        auto *data = new std::shared_ptr<State>(m_state);
        vlc_preparser_req *request =
            vlc_preparser_req_NewThumbnail(m_preparser.get(), item, &arg, &cbs, data);
        input_item_Release(item);
        if (request && vlc_preparser_Submit(m_preparser.get(), request) == VLC_SUCCESS)
            return request;

        if (request)
            vlc_preparser_req_Release(request);
        delete data;
        return nullptr;
    }

    static void onEnded(vlc_preparser_req *, int status, picture_t *thumbnail, void *opaque)
    {
        std::unique_ptr<std::shared_ptr<State>> data(static_cast<std::shared_ptr<State> *>(opaque));
        State &state = **data;

        // Converted before taking the lock, the response may go meanwhile
        QImage image = thumbnail ? toImage(state.obj, thumbnail, state.requestedSize) : QImage();

        std::lock_guard<std::recursive_mutex> guard(state.lock);
        if (!state.response)
            return;
        state.image = image;
        if (image.isNull())
            state.error = status == -EINTR ? QStringLiteral("Cancelled")
                                           : QStringLiteral("No frame decoded");
        emit state.response->finished();
    }

    std::shared_ptr<vlc_preparser_t> m_preparser;
    std::shared_ptr<State> m_state;
    vlc_preparser_req *m_request = nullptr;
};

// Artwork of the media library: looked up and read on the thread of the
// image loader, the response is ready when created
class ArtworkResponse : public QQuickImageResponse
{
public:
    ArtworkResponse(vlc_object_t *obj, const QString &mrl, const QSize &requestedSize)
    {
        const QString path = artworkPath(obj, mrl);
        if (!path.isEmpty())
        {
            QImageReader reader(path);
            reader.setAutoTransform(true);
            const QSize size = reader.size();
            if (size.isValid() && (requestedSize.width() > 0 || requestedSize.height() > 0))
            {
                const QSize bound(requestedSize.width() > 0 ? requestedSize.width() : INT_MAX,
                                  requestedSize.height() > 0 ? requestedSize.height() : INT_MAX);
                if (size.width() > bound.width() || size.height() > bound.height())
                    reader.setScaledSize(size.scaled(bound, Qt::KeepAspectRatio));
            }
            m_image = reader.read();
        }
        if (m_image.isNull())
            m_error = QStringLiteral("No artwork for %1").arg(mrl);
        QMetaObject::invokeMethod(this, &QQuickImageResponse::finished, Qt::QueuedConnection);
    }

    QQuickTextureFactory *textureFactory() const override
    {
        return m_image.isNull() ? nullptr : QQuickTextureFactory::textureFactoryForImage(m_image);
    }

    QString errorString() const override { return m_error; }

private:
    static QString localPath(const vlc_ml_thumbnail_t &thumbnail)
    {
        if (thumbnail.i_status != VLC_ML_THUMBNAIL_STATUS_AVAILABLE || !thumbnail.psz_mrl)
            return {};
        const QUrl url(QString::fromUtf8(thumbnail.psz_mrl));
        return url.isLocalFile() ? url.toLocalFile() : QString();
    }

    static QString artworkPath(vlc_object_t *obj, const QString &mrl)
    {
        vlc_medialibrary_t *ml = vlc_ml_instance_get(obj);
        if (!ml || mrl.isEmpty())
            return {};
        vlc_ml_media_t *media = vlc_ml_get_media_by_mrl(ml, qtu(mrl));
        if (!media)
            return {};
        QString path = localPath(media->thumbnails[VLC_ML_THUMBNAIL_SMALL]);
        if (path.isEmpty() && media->i_subtype == VLC_ML_MEDIA_SUBTYPE_ALBUMTRACK
            && media->album_track.i_album_id > 0)
        {
            if (vlc_ml_album_t *album = vlc_ml_get_album(ml, media->album_track.i_album_id))
            {
                path = localPath(album->thumbnails[VLC_ML_THUMBNAIL_SMALL]);
                vlc_ml_release(album);
            }
        }
        vlc_ml_release(media);
        return path;
    }

    QImage m_image;
    QString m_error;
};

} // anonymous namespace

ThumbnailImageProvider::ThumbnailImageProvider(qt_intf_t *intf)
    : m_intf(intf)
{
}

std::shared_ptr<vlc_preparser_t> ThumbnailImageProvider::preparser()
{
    std::lock_guard<std::mutex> guard(m_lock);
    if (!m_preparser)
    {
        struct vlc_preparser_cfg cfg = {};
        cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
        cfg.max_thumbnailer_threads = 2;
        cfg.timeout = VLC_TICK_FROM_SEC(10);
        cfg.external_process = false;
        vlc_preparser_t *preparser = vlc_preparser_New(VLC_OBJECT(m_intf), &cfg);
        if (preparser)
            m_preparser.reset(preparser, &vlc_preparser_Delete);
    }
    return m_preparser;
}

QQuickImageResponse *ThumbnailImageProvider::requestImageResponse(const QString &id,
                                                                  const QSize &requestedSize)
{
    const QUrlQuery query { QUrl(id) };
    const QString mrl = decodeMrl(query.queryItemValue(QStringLiteral(URL_KEY)));
    if (query.hasQueryItem(QStringLiteral(ARTWORK_KEY)))
        return new ArtworkResponse(VLC_OBJECT(m_intf), mrl, requestedSize);
    bool ok = false;
    const double position = query.queryItemValue(QStringLiteral(POSITION_KEY)).toDouble(&ok);

    return new ThumbnailResponse(mrl.isEmpty() || !ok ? nullptr : preparser(),
                                 VLC_OBJECT(m_intf), mrl, qBound(0.0, position, 1.0),
                                 requestedSize);
}

QString ThumbnailImageProvider::uri(const QString &mrl, double position)
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral(URL_KEY), encodeMrl(mrl));
    query.addQueryItem(QStringLiteral(POSITION_KEY),
                       QString::number(qRound(qBound(0.0, position, 1.0) * 1000) / 1000.0));
    return QStringLiteral("image://%1/?").arg(QLatin1String(providerId))
           + query.toString(QUrl::FullyEncoded);
}

QString ThumbnailImageProvider::artworkUri(const QString &mrl)
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral(URL_KEY), encodeMrl(mrl));
    query.addQueryItem(QStringLiteral(ARTWORK_KEY), QStringLiteral("1"));
    return QStringLiteral("image://%1/?").arg(QLatin1String(providerId))
           + query.toString(QUrl::FullyEncoded);
}

QString VLCThumbnail::artwork(const QString &mrl) const
{
    if (mrl.isEmpty())
        return {};
    return ThumbnailImageProvider::artworkUri(mrl);
}

QString VLCThumbnail::uri(const QString &mrl, double position) const
{
    if (mrl.isEmpty())
        return {};
    return ThumbnailImageProvider::uri(mrl, position);
}
