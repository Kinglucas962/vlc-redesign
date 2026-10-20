/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
import QtQuick.Controls.Basic as Controls

import VLC.MainInterface
import VLC.Style

Controls.MenuItem {
    font.family: VLCStyle.redesign.fontFamily
    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
    palette.text: VLCStyle.redesign.color(VLCStyle.redesign.textSecondary, "#4d4d4d")
    palette.windowText: VLCStyle.redesign.color(VLCStyle.redesign.textSecondary, "#4d4d4d")
    objectName: "hidePlayerUIAction"
    text: MainCtx.minimalView ? qsTr("Show player UI") : qsTr("Hide player UI")
    checkable: true
    checked: MainCtx.minimalView
    onTriggered: {
        MainCtx.minimalView = !MainCtx.minimalView
        // a click toggles the check: follow the view again
        checked = Qt.binding(() => MainCtx.minimalView)
    }
}
