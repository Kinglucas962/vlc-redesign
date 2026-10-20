/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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

import QtQuick
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Style

// The ON / OFF toggle of the design (Figma "Toggle", as the settings): a
// 68 x 32 well (#090909, radius 6) holding a 33 x 26 label (ON in Accent
// Bright at 3 px, OFF in #191919 at 32 px, radius 3) and a 26 x 26 square
// (Accent Dim at 39 px, #404040 at 3 px, radius 3)
T.Switch {
    id: root

    function px(value) { return VLCStyle.dp(value, VLCStyle.scale) }
    function c(value) { return VLCStyle.redesign.color(value, value) }

    // Settings

    width : VLCStyle.checkButton_width
    height: VLCStyle.checkButton_height

    T.ToolTip.visible: (T.ToolTip.text && (hovered || visualFocus))

    T.ToolTip.text: text

    T.ToolTip.delay: VLCStyle.delayToolTipAppear

    // Keys

    Keys.priority: Keys.AfterItem

    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // Accessible

    Accessible.onPressAction: root.clicked()
    Accessible.onToggleAction: root.toggle()

    // Children

    background: Rectangle {
        radius: root.px(6)
        color: root.c("#090909")
        border.width: root.visualFocus ? 1 : 0
        border.color: VLCStyle.redesign.accent
    }

    indicator: Item {
        anchors.fill: parent

        Rectangle {
            x: root.checked ? root.px(3) : root.px(32)
            y: root.px(3)
            width: root.px(33)
            height: root.px(26)
            radius: root.px(3)
            color: root.checked ? root.c(VLCStyle.redesign.accentBackground) : root.c("#191919")

            // ON at (10, 9) of the toggle, OFF at (36, 9), as the design
            Text {
                x: root.checked ? root.px(7) : root.px(4)
                anchors.baseline: parent.top
                anchors.baselineOffset: VLCStyle.redesign.textBaseline(root.px(6), font.pixelSize)
                text: root.checked ? qsTr("ON") : qsTr("OFF")
                color: root.checked ? VLCStyle.redesign.accent : root.c("#6B6B6B")
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: root.px(12)
            }
        }

        Rectangle {
            x: root.checked ? root.px(39) : root.px(3)
            y: root.px(3)
            width: root.px(26)
            height: root.px(26)
            radius: root.px(3)
            color: root.checked ? VLCStyle.redesign.accentDim : root.c("#404040")
        }
    }
}
