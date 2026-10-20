/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#include "mlfrequentfoldersmodel.hpp"

#include "medialib.hpp"
#include "mlhelper.hpp"

#include <vlc_media_library.h>

#include <QDir>
#include <QFileInfo>
#include <QHash>

#include <algorithm>

namespace {

// History entries looked at: enough for the folders of recent weeks
constexpr uint32_t historyDepth = 300;

} // anonymous namespace

MLFrequentFoldersModel::MLFrequentFoldersModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_eventHandle(nullptr, [this](vlc_ml_event_callback_t *cb) {
        if (cb && m_ml)
            m_ml->unregisterEventListener(cb);
    })
{
}

MLFrequentFoldersModel::~MLFrequentFoldersModel()
{
    // Unregistered before the members it uses go
    m_eventHandle.reset();
}

void MLFrequentFoldersModel::setMl(MediaLib *ml)
{
    if (m_ml == ml)
        return;
    m_eventHandle.reset();
    m_ml = ml;
    if (m_ml)
        m_eventHandle.reset(m_ml->registerEventListener(&MLFrequentFoldersModel::onMlEvent, this));
    emit mlChanged();
    reload();
}

void MLFrequentFoldersModel::setLimit(int limit)
{
    if (m_limit == limit)
        return;
    m_limit = limit;
    emit limitChanged();
    reload();
}

void MLFrequentFoldersModel::onMlEvent(void *data, const vlc_ml_event_t *event)
{
    // Called on a thread of the media library
    if (event->i_type != VLC_ML_EVENT_HISTORY_CHANGED)
        return;
    auto *self = static_cast<MLFrequentFoldersModel *>(data);
    QMetaObject::invokeMethod(self, &MLFrequentFoldersModel::reload, Qt::QueuedConnection);
}

void MLFrequentFoldersModel::reload()
{
    if (!m_ml)
    {
        beginResetModel();
        m_folders.clear();
        endResetModel();
        emit countChanged();
        return;
    }

    struct Ctx
    {
        std::vector<Folder> folders;
    };

    const int limit = m_limit;
    m_ml->runOnMLThread<Ctx>(this,
    // ML thread
    [limit](vlc_medialibrary_t *ml, Ctx &ctx)
    {
        vlc_ml_query_params_t params = vlc_ml_query_params_create();
        params.i_nbResults = historyDepth;
        ml_unique_ptr<vlc_ml_media_list_t> history{
            vlc_ml_list_history(ml, &params, VLC_ML_HISTORY_TYPE_LOCAL)
        };
        if (!history)
            return;

        // History order (most recent first) breaks the ties
        QHash<QString, size_t> positions;
        for (const vlc_ml_media_t &media : ml_range_iterate<vlc_ml_media_t>(history))
        {
            const char *mrl = nullptr;
            if (media.p_files)
                for (const vlc_ml_file_t &file : ml_range_iterate<vlc_ml_file_t>(media.p_files))
                    if (file.i_type == VLC_ML_FILE_TYPE_MAIN && file.psz_mrl)
                    {
                        mrl = file.psz_mrl;
                        break;
                    }
            if (!mrl)
                continue;
            const QUrl url = QUrl::fromEncoded(mrl);
            if (!url.isLocalFile())
                continue;

            const QString folder = QFileInfo(url.toLocalFile()).absolutePath();
            const unsigned plays = std::max<uint32_t>(media.i_playcount, 1);
            const bool video = media.i_type == VLC_ML_MEDIA_TYPE_VIDEO;
            auto it = positions.constFind(folder);
            if (it == positions.cend())
            {
                positions.insert(folder, ctx.folders.size());
                const QString name = QDir(folder).dirName();
                ctx.folders.push_back({ name.isEmpty() ? QDir::toNativeSeparators(folder) : name,
                                        QUrl::fromLocalFile(folder), plays,
                                        video ? url : QUrl() });
            }
            else
            {
                Folder &entry = ctx.folders[it.value()];
                entry.plays += plays;
                if (entry.preview.isEmpty() && video)
                    entry.preview = url;
            }
        }

        std::stable_sort(ctx.folders.begin(), ctx.folders.end(),
                         [](const Folder &a, const Folder &b) { return a.plays > b.plays; });
        if (limit > 0 && ctx.folders.size() > static_cast<size_t>(limit))
            ctx.folders.resize(limit);
    },
    // UI thread
    [this](quint64, Ctx &ctx)
    {
        beginResetModel();
        m_folders = std::move(ctx.folders);
        endResetModel();
        emit countChanged();
    });
}

int MLFrequentFoldersModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : count();
}

QVariant MLFrequentFoldersModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= count())
        return {};
    const Folder &folder = m_folders[index.row()];
    switch (role)
    {
    case Qt::DisplayRole:
    case NameRole:
        return folder.name;
    case UrlRole:
        return folder.url;
    case PlaysRole:
        return folder.plays;
    case PreviewRole:
        return folder.preview;
    default:
        return {};
    }
}

QHash<int, QByteArray> MLFrequentFoldersModel::roleNames() const
{
    return {
        { NameRole, "name" },
        { UrlRole, "url" },
        { PlaysRole, "plays" },
        { PreviewRole, "preview" },
    };
}
