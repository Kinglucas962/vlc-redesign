/****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * SPDX-License-Identifier: GPL-2.0-or-later
 ****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Style
import VLC.Util

Item {
    id: root
    objectName: "privacyHistoryActions"
    implicitHeight: VLCStyle.dp(42, VLCStyle.scale)
    readonly property bool available: MainCtx.mediaLibraryAvailable
    readonly property bool dark: VLCStyle.palette.isDark

    MLRecentMediaModel {
        id: recentMedia
        ml: MainCtx.mediaLibraryAvailable ? MediaLib : null
    }

    // Clear history now: label, (i) and the 100 px Clear button of the design
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: VLCStyle.dp(10, VLCStyle.scale)
        Text {
            anchors.baseline: parent.verticalCenter
            anchors.baselineOffset: VLCStyle.redesign.centeredBaseline(font.pixelSize)
            text: qsTr("Clear history now")
            color: VLCStyle.redesign.color("#8F8F8F", "#8F8F8F")
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        }
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(18, VLCStyle.scale)
            height: width
            sourceSize: Qt.size(width, height)
            source: SVGColorImage.colorize("qrc:///redesign/duo/info-small.svg")
                                 .color1(VLCStyle.redesign.color("#404040", "#404040")).uri()
            HoverHandler { id: clearHelpHover }
            ToolTip.visible: clearHelpHover.hovered
            ToolTip.text: root.available ? qsTr("Removes the recently played items of the media library.")
                                         : qsTr("Media library unavailable")
            ToolTip.delay: 650
        }
    }

    SettingsButton {
        id: clearButton
        objectName: "clearRecentHistory"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: qsTr("Clear")
        enabled: root.available
        onClicked: confirmClear.open()
    }

    Dialog {
        id: confirmClear
        objectName: "confirmClearRecentHistory"
        parent: root.parent
        anchors.centerIn: parent
        // The wrapped label has no implicit width of its own (binding loop)
        width: VLCStyle.dp(420, VLCStyle.scale)
        modal: true
        title: qsTr("Clear playback history?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            if (root.available)
                recentMedia.clearHistory()
        }
        contentItem: Label {
            text: qsTr("Recently played items will be removed from the media library.")
            wrapMode: Text.WordWrap
            color: root.dark ? "#dddddd" : "#333333"
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        }
    }
}
