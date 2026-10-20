/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "local_folder_model.hpp"

#include "medialibrary/medialib.hpp"
#include "medialibrary/mlhelper.hpp"

#include <QCollator>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QSet>

#include <algorithm>

#include <vlc_common.h>
#include <vlc_interface.h>
#include <vlc_media_library.h>
#include <vlc_url.h>

#include <vector>

namespace {
// Suffixes of the files VLC opens, from "*.mkv;*.mp4;..."
const QSet<QString>& mediaSuffixes()
{
    static const QSet<QString> suffixes = [] {
        QSet<QString> set;
        const QString patterns = QStringLiteral(EXTENSIONS_VIDEO ";" EXTENSIONS_AUDIO ";" EXTENSIONS_PLAYLIST);
        for (const QString& pattern : patterns.split(QLatin1Char(';'), Qt::SkipEmptyParts))
            set.insert(pattern.mid(2).toLower()); // drop "*."
        return set;
    }();
    return suffixes;
}
}

LocalFolderModel::LocalFolderModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

void LocalFolderModel::setFolder(const QUrl& folder)
{
    if (folder == m_folder)
        return;
    m_folder = folder;
    emit folderChanged();
    reload();
}

QUrl LocalFolderModel::parentFolder() const
{
    if (!m_folder.isLocalFile())
        return {};
    QDir dir(m_folder.toLocalFile());
    if (!dir.cdUp())
        return {};
    return QUrl::fromLocalFile(dir.absolutePath());
}

QString LocalFolderModel::folderName() const
{
    if (!m_folder.isLocalFile())
        return {};
    const QFileInfo info(m_folder.toLocalFile());
    // A drive root has no name: show "C:" rather than nothing
    return info.fileName().isEmpty() ? QDir::toNativeSeparators(info.absoluteFilePath()).remove(QLatin1Char('\\'))
                                     : info.fileName();
}

void LocalFolderModel::setSearchPattern(const QString& pattern)
{
    if (pattern == m_searchPattern)
        return;
    m_searchPattern = pattern;
    emit searchPatternChanged();
    reload();
}

void LocalFolderModel::setSortCriteria(const QString& criteria)
{
    if (criteria == m_sortCriteria)
        return;
    m_sortCriteria = criteria;
    emit sortChanged();
    reload();
}

void LocalFolderModel::setSortOrder(Qt::SortOrder order)
{
    if (order == m_sortOrder)
        return;
    m_sortOrder = order;
    emit sortChanged();
    reload();
}

QUrl LocalFolderModel::folderOf(const QUrl& media)
{
    if (!media.isLocalFile())
        return {};
    return QUrl::fromLocalFile(QFileInfo(media.toLocalFile()).absolutePath());
}

void LocalFolderModel::reload()
{
    beginResetModel();
    m_entries.clear();
    if (m_folder.isLocalFile())
    {
        const QDir dir(m_folder.toLocalFile());
        const QFileInfoList infos = dir.entryInfoList(QDir::AllDirs | QDir::Files | QDir::NoDotAndDotDot
                                                      | QDir::Readable);
        for (const QFileInfo& info : infos)
        {
            const bool isFolder = info.isDir();
            if (!isFolder && !mediaSuffixes().contains(info.suffix().toLower()))
                continue;
            if (!m_searchPattern.isEmpty() && !info.fileName().contains(m_searchPattern, Qt::CaseInsensitive))
                continue;
            m_entries.push_back({ info.fileName(), QUrl::fromLocalFile(info.absoluteFilePath()), isFolder,
                                  info.lastModified().toMSecsSinceEpoch() });
        }
        sortEntries();
    }
    ++m_generation;
    endResetModel();
    emit countChanged();
    loadLibraryData();
}

void LocalFolderModel::sortEntries()
{
    // Folders first, then names the way people read them (2 before 10)
    QCollator collator;
    collator.setNumericMode(true);
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    const bool byDate = m_sortCriteria == QLatin1String("date");
    const bool byWatched = m_sortCriteria == QLatin1String("unwatched");
    const bool descending = m_sortOrder == Qt::DescendingOrder;
    const auto played = [](const Entry& e) { return e.playCount > 0 || e.progress > 0.; };
    std::sort(m_entries.begin(), m_entries.end(), [&](const Entry& a, const Entry& b) {
        if (a.isFolder != b.isFolder)
            return a.isFolder;
        if (byWatched && played(a) != played(b))
            return descending ? played(a) : played(b);
        const int order = byDate ? (a.modified < b.modified ? -1 : a.modified > b.modified)
                                 : collator.compare(a.name, b.name);
        return (descending && !byWatched) ? order > 0 : order < 0;
    });
}

void LocalFolderModel::setMl(MediaLib* ml)
{
    if (m_ml == ml)
        return;
    m_ml = ml;
    emit mlChanged();
    loadLibraryData();
}

void LocalFolderModel::loadLibraryData()
{
    if (!m_ml || m_entries.isEmpty())
        return;

    // The MRLs the library stores (vlc_path2uri) of the media of the folder
    std::vector<std::pair<int, QByteArray>> mrls;
    for (int i = 0; i < m_entries.size(); ++i)
    {
        if (m_entries[i].isFolder)
            continue;
        const QByteArray path = QDir::toNativeSeparators(m_entries[i].url.toLocalFile()).toUtf8();
        char* mrl = vlc_path2uri(path.constData(), "file");
        if (!mrl)
            continue;
        mrls.emplace_back(i, QByteArray(mrl));
        free(mrl);
    }
    if (mrls.empty())
        return;

    struct Result
    {
        int row;
        double progress;
        unsigned playCount;
        int64_t id;
        bool favorite;
    };
    struct Ctx
    {
        std::vector<Result> results;
    };
    const quint64 generation = m_generation;
    m_ml->runOnMLThread<Ctx>(this,
    // ML thread
    [mrls](vlc_medialibrary_t* ml, Ctx& ctx)
    {
        for (const auto& entry : mrls)
        {
            ml_unique_ptr<vlc_ml_media_t> media{ vlc_ml_get_media_by_mrl(ml, entry.second.constData()) };
            if (media)
                ctx.results.push_back({ entry.first, media->f_progress, media->i_playcount,
                                        media->i_id, media->b_is_favorite });
        }
    },
    // UI thread
    [this, generation](quint64, Ctx& ctx)
    {
        if (generation != m_generation || ctx.results.empty())
            return;
        for (const auto& result : ctx.results)
        {
            if (result.row >= m_entries.size())
                continue;
            Entry& entry = m_entries[result.row];
            entry.progress = result.progress > 0. ? result.progress : 0.;
            entry.playCount = result.playCount;
            entry.mlId = result.id;
            entry.favorite = result.favorite;
        }
        if (m_sortCriteria == QLatin1String("unwatched"))
        {
            // the order depends on what was played
            beginResetModel();
            sortEntries();
            endResetModel();
            return;
        }
        emit dataChanged(index(0), index(m_entries.size() - 1),
                         { ProgressRole, PlayCountRole, IsFavoriteRole, IsIndexedRole });
    });
}

int LocalFolderModel::rowCount(const QModelIndex& parent) const
{
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant LocalFolderModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= m_entries.size())
        return {};
    const Entry& entry = m_entries[index.row()];
    switch (role)
    {
    case Qt::DisplayRole:
    case NameRole:
        return entry.name;
    case UrlRole:
        return entry.url;
    case IsFolderRole:
        return entry.isFolder;
    case ProgressRole:
        return entry.progress;
    case PlayCountRole:
        return entry.playCount;
    case IsFavoriteRole:
        return entry.favorite;
    case IsIndexedRole:
        return entry.mlId > 0;
    default:
        return {};
    }
}

MLItemId LocalFolderModel::mediaId(int row) const
{
    if (row < 0 || row >= m_entries.size() || m_entries[row].mlId <= 0)
        return {};
    return MLItemId(m_entries[row].mlId, VLC_ML_PARENT_UNKNOWN);
}

void LocalFolderModel::setPlayed(int row, bool played)
{
    if (!m_ml || row < 0 || row >= m_entries.size() || m_entries[row].mlId <= 0)
        return;
    const int64_t id = m_entries[row].mlId;
    m_ml->runOnMLThread(this,
    [id, played](vlc_medialibrary_t* ml)
    {
        vlc_ml_media_set_played(ml, id, played);
    },
    // the progress and the play count again (and the order of "unwatched")
    [this]() { loadLibraryData(); });
}

void LocalFolderModel::setFavorite(int row, bool favorite)
{
    if (!m_ml || row < 0 || row >= m_entries.size() || m_entries[row].mlId <= 0)
        return;
    const int64_t id = m_entries[row].mlId;
    m_entries[row].favorite = favorite;
    emit dataChanged(index(row), index(row), { IsFavoriteRole });
    m_ml->runOnMLThread(this,
    [id, favorite](vlc_medialibrary_t* ml)
    {
        vlc_ml_media_set_favorite(ml, id, favorite);
    });
}

QHash<int, QByteArray> LocalFolderModel::roleNames() const
{
    return {
        { NameRole, "name" },
        { UrlRole, "url" },
        { IsFolderRole, "isFolder" },
        { ProgressRole, "progress" },
        { PlayCountRole, "playcount" },
        { IsFavoriteRole, "isFavorite" },
        { IsIndexedRole, "isIndexed" },
    };
}
