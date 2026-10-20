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
#ifndef THUMBNAIL_IMAGE_PROVIDER_HPP
#define THUMBNAIL_IMAGE_PROVIDER_HPP

#include <QObject>
#include <QQuickAsyncImageProvider>
#include <QString>

#include <memory>
#include <mutex>

#include "qt.hpp"

typedef struct vlc_preparser_t vlc_preparser_t;

/**
 * Frames of media decoded by the thumbnailer of the preparser, for previews
 * (seek bar, files of a folder): image://vlcthumbnail/?url=<mrl>&pos=<0..1>
 */
class ThumbnailImageProvider : public QQuickAsyncImageProvider
{
public:
    static constexpr const char *providerId = "vlcthumbnail";

    explicit ThumbnailImageProvider(qt_intf_t *intf);

    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

    static QString uri(const QString &mrl, double position);
    static QString artworkUri(const QString &mrl);

private:
    std::shared_ptr<vlc_preparser_t> preparser();

    qt_intf_t *m_intf;
    std::mutex m_lock;
    // Created on first use, kept alive by the pending requests
    std::shared_ptr<vlc_preparser_t> m_preparser;
};

class VLCThumbnail : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;

    /**
     * Image source of the frame of @mrl at @position (0 to 1); positions
     * are rounded to a thousandth so that close requests share the cache.
     *
     * @code{qml}
     *   Image {
     *     source: VLCThumbnail.uri(Player.url, 0.5)
     *     sourceSize: Qt.size(240, 135)
     *   }
     * @endcode
     */
    Q_INVOKABLE QString uri(const QString &mrl, double position) const;

    /**
     * Image source of the artwork the media library has for @mrl (cover of
     * a song or of its album); fails to load when it has none.
     */
    Q_INVOKABLE QString artwork(const QString &mrl) const;
};

#endif // THUMBNAIL_IMAGE_PROVIDER_HPP
