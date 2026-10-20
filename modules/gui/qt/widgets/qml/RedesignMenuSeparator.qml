/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T

import VLC.Style

// Separator of a RedesignMenu: a 1px line between groups of rows
T.MenuSeparator {
    id: root

    // false: the place of a separator without its line (Figma's main menu
    // has one between Open Recent and Profile)
    property bool line: true

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: implicitContentHeight

    contentItem: Rectangle {
        implicitHeight: 1
        color: root.line ? VLCStyle.redesign.color(VLCStyle.redesign.separator, "#9c9c9b")
                           : "transparent"
    }
}
