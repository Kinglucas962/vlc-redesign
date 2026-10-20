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

#ifndef ML_FREQUENT_FOLDERS_MODEL_HPP
#define ML_FREQUENT_FOLDERS_MODEL_HPP

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <QAbstractListModel>
#include <QUrl>

#include <functional>
#include <memory>
#include <vector>

class MediaLib;
Q_MOC_INCLUDE("medialibrary/medialib.hpp")
struct vlc_ml_event_callback_t;
struct vlc_ml_event_t;

/**
 * Local folders of the playback history, the most played first ("Frequently
 * Visited Folders" of the home page). A folder counts the plays of its media.
 */
class MLFrequentFoldersModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(MediaLib* ml READ ml WRITE setMl NOTIFY mlChanged FINAL)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)

public:
    enum Roles
    {
        NameRole = Qt::UserRole + 1,
        UrlRole,
        PlaysRole,
        // A video of the folder, for a preview frame
        PreviewRole
    };

    explicit MLFrequentFoldersModel(QObject *parent = nullptr);
    ~MLFrequentFoldersModel() override;

    MediaLib *ml() const { return m_ml; }
    void setMl(MediaLib *ml);
    int limit() const { return m_limit; }
    void setLimit(int limit);
    int count() const { return static_cast<int>(m_folders.size()); }

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

signals:
    void mlChanged();
    void limitChanged();
    void countChanged();

private:
    struct Folder
    {
        QString name;
        QUrl url;
        unsigned plays = 0;
        QUrl preview;
    };

    void reload();
    static void onMlEvent(void *data, const vlc_ml_event_t *event);

    MediaLib *m_ml = nullptr;
    int m_limit = 8;
    std::vector<Folder> m_folders;
    std::unique_ptr<vlc_ml_event_callback_t, std::function<void(vlc_ml_event_callback_t *)>> m_eventHandle;
};

#endif // ML_FREQUENT_FOLDERS_MODEL_HPP
