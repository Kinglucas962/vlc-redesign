/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
import QtQuick
import VLC.Player
import VLC.MainInterface
import VLC.PlayerControls

MetadataText {
    id: root
    value: details.resolution
    placeholder: qsTr("Resolution unavailable")
    PlayerMediaDetails { id: details; ctx: MainCtx; url: Player.url }
    Connections {
        target: Player.videoTracks
        function onCountChanged() { details.refresh() }
        function onDataChanged() { details.refresh() }
        function onModelReset() { details.refresh() }
    }
}
