/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls.Basic as Controls

import VLC.Dialogs
import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Player
import VLC.PlayerControls
import VLC.Style

ColumnLayout {
    id: root
    objectName: "subtitleTracksPanel"
    spacing: VLCStyle.dp(8, VLCStyle.scale)
    property var reveal: null
    readonly property bool localMedia: Player.url.toString().startsWith("file://")
    // Tracks of subtitle files added to the media (TrackListModel.ExternalRole)
    readonly property int externalCount: {
        let count = 0
        for (let i = 0; i < Player.subtitleTracks.count; ++i)
            if (Player.subtitleTracks.data(Player.subtitleTracks.index(i, 0), Qt.UserRole + 1))
                ++count
        return count
    }

    SubtitleAssociationsDialog {
        id: associationsDialog
        parent: Controls.Overlay.overlay
    }

    Text {
        Layout.fillWidth: true
        text: qsTr("Embedded Tracks")
        color: VLCStyle.redesign.color("#6B6B6B", "#5a5a59")
        font.family: VLCStyle.redesign.fontFamily
        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
    }

    ActionButton {
        objectName: "subtitleOffButton"
        Layout.fillWidth: true
        text: qsTr("None")
        checked: {
            for (let i = 0; i < Player.subtitleTracks.count; ++i)
                if (Player.subtitleTracks.data(Player.subtitleTracks.index(i, 0), Qt.CheckStateRole))
                    return false
            return true
        }
        onClicked: {
            for (let i = 0; i < Player.subtitleTracks.count; ++i) {
                const index = Player.subtitleTracks.index(i, 0)
                if (Player.subtitleTracks.data(index, Qt.CheckStateRole))
                    Player.subtitleTracks.setData(index, false, Qt.CheckStateRole)
            }
        }
    }

    Repeater {
        model: Player.subtitleTracks
        delegate: ActionButton {
            objectName: "subtitleTrack" + index
            Layout.fillWidth: true
            visible: !model.external
            text: model.display
            checked: model.checked
            onClicked: model.checked = !model.checked
        }
    }

    // Subtitle files loaded for this media, in their own list; the header
    // adds them to the library (edit) or loads one for playback (add)
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.dp(12, VLCStyle.scale)
        spacing: VLCStyle.dp(4, VLCStyle.scale)

        Text {
            Layout.fillWidth: true
            text: qsTr("External Tracks")
            color: VLCStyle.redesign.color("#6B6B6B", "#5a5a59")
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
        }

        HeaderButton {
            objectName: "associateSubtitleButton"
            iconName: "edit"
            description: root.localMedia && MainCtx.mediaLibraryAvailable
                         ? qsTr("Add subtitles to the library")
                         : qsTr("Library association needs a local media file and media library.")
            enabled: root.localMedia && MainCtx.mediaLibraryAvailable
            onClicked: associationsDialog.openForUrl(Player.url)
        }

        HeaderButton {
            objectName: "addSubtitleButton"
            iconName: "add"
            description: qsTr("Load a subtitle file for playback")
            onClicked: DialogsProvider.loadSubtitlesFile()
        }
    }

    Repeater {
        model: Player.subtitleTracks
        delegate: ActionButton {
            objectName: "externalSubtitleTrack" + index
            Layout.fillWidth: true
            visible: model.external
            text: model.display
            checked: model.checked
            onClicked: model.checked = !model.checked
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.dp(8, VLCStyle.scale)
        implicitHeight: 1
        color: VLCStyle.redesign.color("#222222", "#9c9c9b")
    }

    SubtitleSyncTimeline {
        Layout.fillWidth: true
        presets: SubtitleSeriesPreset
        reveal: root.reveal
    }

    component HeaderButton: T.Button {
        id: headerButton

        property string iconName
        property string description

        implicitWidth: VLCStyle.dp(32, VLCStyle.scale)
        implicitHeight: VLCStyle.dp(32, VLCStyle.scale)
        focusPolicy: Qt.StrongFocus
        Accessible.name: description
        T.ToolTip.visible: hovered && description.length > 0
        T.ToolTip.text: description
        T.ToolTip.delay: VLCStyle.delayToolTipAppear

        background: Rectangle {
            radius: VLCStyle.redesign.controlRadius
            color: headerButton.hovered || headerButton.down ? VLCStyle.redesign.color("#222222", "#9c9c9b") : "transparent"
            border.width: headerButton.visualFocus ? 1 : 0
            border.color: VLCStyle.redesign.focusColor
        }
        contentItem: Image {
            source: "qrc:///redesign/icons/" + headerButton.iconName + "/default.png"
            sourceSize: Qt.size(VLCStyle.redesign.iconSize, VLCStyle.redesign.iconSize)
            fillMode: Image.Pad
            opacity: headerButton.enabled ? 1 : 0.4
        }
    }

    component ActionButton: T.Button {
        implicitHeight: VLCStyle.dp(40, VLCStyle.scale)
        checkable: false
        focusPolicy: Qt.StrongFocus
        onActiveFocusChanged: if (activeFocus && root.reveal) root.reveal(this)
        background: Rectangle {
            color: parent.hovered || parent.activeFocus ? VLCStyle.redesign.color("#151515", "#9c9c9b") : "transparent"
            border.width: parent.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: VLCStyle.redesign.focusColor
            radius: VLCStyle.dp(4, VLCStyle.scale)
        }
        contentItem: Item {
            Image {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:///redesign/track-check-active.png"
                visible: parent.parent.checked
                width: VLCStyle.dp(24, VLCStyle.scale)
                height: width
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(40, VLCStyle.scale)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.text
                color: VLCStyle.redesign.color(VLCStyle.redesign.textSecondary, "#2e2e2e")
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                elide: Text.ElideRight
            }
        }
    }
}
