/****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * SPDX-License-Identifier: GPL-2.0-or-later
 ****************************************************************************/
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#include "config_model.hpp"
#include "config_values.hpp"
#include "dialogs/extended/audio_effects.hpp"
#include "dialogs/extended/video_effects.hpp"
#include "maininterface/mainctx.hpp"

#include <iterator>

// VLC options written for a combined entry (see addCombinedEntries)
bool ConfigModel::combinedValues(const Entry &entry, QHash<QString, QVariant> *values,
                                 QHash<QString, QVariant> *expected)
{
    const qlonglong mode = entry.staged.toLongLong();
    QStringList keys;
    if (entry.key == QLatin1String(repeatKey)) {
        values->insert(QStringLiteral("repeat"), mode == 1);
        values->insert(QStringLiteral("loop"), mode == 2);
        keys = { QStringLiteral("repeat"), QStringLiteral("loop") };
    } else if (entry.key == QLatin1String(playbackEndKey)) {
        values->insert(QStringLiteral("play-and-exit"), mode == 1);
        keys = { QStringLiteral("play-and-exit") };
    } else if (entry.key == QLatin1String(seekPreciseKey)) {
        values->insert(QStringLiteral("input-fast-seek"), !entry.staged.toBool());
        keys = { QStringLiteral("input-fast-seek") };
    } else if (entry.key == QLatin1String(postprocKey)) {
        QStringList filters = ConfigValues::read(QStringLiteral("video-filter")).toString()
                                  .split(':', Qt::SkipEmptyParts);
        filters.removeAll(QStringLiteral("postproc"));
        if (mode > 0) {
            filters.append(QStringLiteral("postproc"));
            values->insert(QStringLiteral("postproc-q"), QVariant::fromValue<int64_t>(mode));
            keys.append(QStringLiteral("postproc-q"));
        }
        values->insert(QStringLiteral("video-filter"), filters.join(':'));
        keys.append(QStringLiteral("video-filter"));
    } else if (entry.key == QLatin1String(ignoreAssStylingKey)) {
        values->insert(QStringLiteral("subsdec-formatted"), !entry.staged.toBool());
        keys = { QStringLiteral("subsdec-formatted") };
    } else if (entry.key == QLatin1String(visualSizeKey)) {
        // the size of the user stays while it is chosen
        if (mode < 0 || mode >= qlonglong(std::size(visualSizes)))
            return true;
        values->insert(QStringLiteral("effect-width"), QVariant::fromValue<int64_t>(visualSizes[mode][0]));
        values->insert(QStringLiteral("effect-height"), QVariant::fromValue<int64_t>(visualSizes[mode][1]));
        keys = { QStringLiteral("effect-width"), QStringLiteral("effect-height") };
    } else if (entry.key == QLatin1String(customSkinKey)) {
        // Off: back to the default interface, unless another one was chosen
        const QString intf = ConfigValues::read(QStringLiteral("intf")).toString();
        values->insert(QStringLiteral("intf"), entry.staged.toBool() ? QStringLiteral("skins2")
                                               : intf == QLatin1String("skins2") ? QString() : intf);
        keys = { QStringLiteral("intf") };
    } else {
        return false;
    }
    for (const QString &key : keys)
        expected->insert(key, ConfigValues::read(key));
    return true;
}

bool ConfigModel::applyWithEffects(AudioEffects *audio, VideoEffects *video)
{
    const auto cancelPreview = [audio, video]() {
        bool restored = true;
        if (audio && !audio->cancel()) restored = false;
        if (video && !video->cancel()) restored = false;
        return restored;
    };
    if (!m_ctx || !m_ctx->getIntf()) {
        setError(tr("VLC preferences are unavailable."));
        cancelPreview();
        return false;
    }
    if ((audio && audio->ctx() != m_ctx) || (video && video->ctx() != m_ctx)) {
        setError(tr("The effect preview belongs to another VLC window."));
        cancelPreview();
        return false;
    }

    QHash<QString, QVariant> values, expected;
    QVector<int> changed, changedQt;
    for (int i = 0; i < m_entries.size(); ++i) {
        const Entry& entry = m_entries[i];
        if (entry.staged == entry.current) continue;
        if (entry.qtSetting) {
            changedQt.append(i);
            continue;
        }
        // written by the option it stands for
        if (!entry.proxyFor.isEmpty())
            continue;
        if (readValue(entry) != entry.current) {
            setError(tr("%1 changed outside this dialog. Cancel and reopen preferences.").arg(entry.label));
            cancelPreview();
            return false;
        }
        changed.append(i);
        if (!combinedValues(entry, &values, &expected)) {
            values.insert(entry.key, entry.staged);
            expected.insert(entry.key, entry.current);
        }
    }
    if (audio && !audio->prepareConfiguration(values, expected)) {
        setError(audio->lastError());
        cancelPreview();
        return false;
    }
    if (video && !video->prepareConfiguration(values, expected)) {
        setError(video->lastError());
        cancelPreview();
        return false;
    }

    QString conflict;
    int result = 0;
    if (!ConfigValues::commit(m_ctx->getIntf(), values, expected, &conflict, &result)) {
        const bool restored = cancelPreview();
        if (result)
            setError(tr("Could not save VLC preferences (error %1). Configuration was restored in memory; verify the file.").arg(result)
                     + (restored ? QString() : tr(" The playback preview could not be restored.")));
        else
            setError(tr("%1 changed outside this dialog or is unavailable. Changes were not saved.").arg(conflict)
                     + (restored ? QString() : tr(" The playback preview could not be restored.")));
        return false;
    }
    if (audio) audio->finalizeConfiguration();
    if (video) video->finalizeConfiguration();
    for (int i : changedQt)
        m_ctx->setSettingValue(m_entries[i].key, m_entries[i].staged);
    changed += changedQt;
    for (int i : changed) {
        m_entries[i].current = m_entries[i].staged;
        notifyEntry(i);
    }
    syncDerived();
    if (!changed.isEmpty()) {
        // Interface options (pinned controls, seek thumbnail...) apply now
        m_ctx->reloadPrefs();
        emit dirtyChanged();
    }
    setError({});
    return true;
}
