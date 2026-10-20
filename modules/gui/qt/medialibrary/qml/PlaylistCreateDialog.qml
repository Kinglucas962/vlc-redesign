/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

// Figma "new playlist" (713 wide): "Frame 499" (the title and its field,
// the thumbnail at the bottom of the row), a line, "Select Files" and the
// box where the files are dropped or chosen
Widgets.RedesignDialog {
    id: root
    objectName: "playlistCreateDialog"

    required property MLPlaylistListModel playlistModel
    property var files: []

    title: qsTr("New Playlist")
    acceptText: qsTr("Save")
    acceptEnabled: titleField.text.trim().length > 0 && root.files.length > 0
                   && !root.playlistModel.transactionPending
    preferredWidth: VLCStyle.dp(713, VLCStyle.scale)

    // Figma 6259:14954 opens with no field focused (no caret)
    initialField: titleField
    onClosed: {
        titleField.clear()
        files = []
    }
    onAccepted: playlistModel.create(titleField.text.trim(), files)

    function createPlaylist() {
        root.accept()
    }

    function chooseFiles() {
        const selected = filePicker.chooseFiles(qsTr("Add files to playlist"))
        if (selected.length > 0)
            root.files = root.files.concat(selected)
    }

    Widgets.FilePicker { id: filePicker; ctx: MainCtx }

    // Figma "Icon Wrapper" of the boxes: 30 high, #161616, the add icon
    component AddWrapper: Rectangle {
        property bool hovered: false
        // "half": the raster of the design where it draws the icon on half
        // pixels (the button of the drop box)
        property string icon: "default"

        radius: VLCStyle.dp(4, VLCStyle.scale)
        color: hovered ? VLCStyle.redesign.color("#222222", "#9c9c9b", root.darkTheme)
                       : VLCStyle.redesign.color("#161616", "#b8b8b7", root.darkTheme)
        Image {
            anchors.centerIn: parent
            source: "qrc:///redesign/icons/add/" + parent.icon + ".png"
            sourceSize: Qt.size(VLCStyle.redesign.iconSize, VLCStyle.redesign.iconSize)
            smooth: false
        }
    }

    // "Frame 499": 20 apart, the thumbnail at the bottom
    RowLayout {
        Layout.fillWidth: true
        spacing: VLCStyle.dp(20, VLCStyle.scale)

        // "Frame 498": the title, 20 above its field
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: VLCStyle.dp(20, VLCStyle.scale)

            Widgets.RedesignDialogHeading {
                text: qsTr("Playlist Details")
                description: qsTr("The playlist will be saved and displayed with this title and thumbnail.")
            }

            Widgets.RedesignTextArea {
                id: titleField

                objectName: "playlistTitleField"
                placeholderText: qsTr("e.g., Favorite Videos")
                Accessible.name: qsTr("Playlist title")
                onAccepted: root.accept()
            }
        }

        // "Frame 326" (112 x 112): the thumbnail, from the media (the
        // frame of the first video), else the add button
        T.Button {
            id: thumbnail

            readonly property string firstVideo: {
                for (const file of root.files) {
                    const url = String(file)
                    if (/\.(3gp|avi|flv|m2ts|m4v|mkv|mov|mp4|mpe?g|mts|ogv|ts|webm|wmv)$/i.test(url))
                        return url
                }
                return ""
            }

            Layout.preferredWidth: VLCStyle.dp(112, VLCStyle.scale)
            Layout.preferredHeight: VLCStyle.dp(112, VLCStyle.scale)
            Layout.alignment: Qt.AlignBottom
            Accessible.name: qsTr("Choose files")

            background: Rectangle {
                radius: VLCStyle.dp(6, VLCStyle.scale)
                color: VLCStyle.redesign.color("#090909", "#dedede", root.darkTheme)
                border.width: VLCStyle.dp(2, VLCStyle.scale)
                border.color: thumbnail.visualFocus ? VLCStyle.redesign.focusColor
                                                    : VLCStyle.redesign.color("#191919", "#c4c4c3", root.darkTheme)
            }
            contentItem: Item {
                Image {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
                    visible: status === Image.Ready
                    source: thumbnail.firstVideo !== "" ? VLCThumbnail.uri(thumbnail.firstVideo, 0.1) : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                AddWrapper {
                    anchors.centerIn: parent
                    width: VLCStyle.dp(30, VLCStyle.scale)
                    height: VLCStyle.dp(30, VLCStyle.scale)
                    visible: thumbnail.firstVideo === ""
                    hovered: thumbnail.hovered
                }
            }
            onClicked: root.chooseFiles()
        }
    }

    // "Vector": 1 px of "Dark/Divider/Dim" (#222222) centred between the
    // rows, which puts it half on two lines of pixels
    Item {
        Layout.fillWidth: true
        implicitHeight: 0
        Rectangle {
            y: -VLCStyle.dp(1, VLCStyle.scale)
            width: parent.width
            height: VLCStyle.dp(2, VLCStyle.scale)
            color: root.darkTheme ? Qt.rgba(34 / 255, 34 / 255, 34 / 255, 0.5) : Qt.rgba(0.61, 0.61, 0.61, 0.5)
        }
    }

    Widgets.RedesignDialogHeading {
        text: qsTr("Select Files")
        description: qsTr("These files will be added to the playlist.")
    }

    // "Frame 206" (186 high), "Frame 86": #090909, radius 6, a dashed
    // border of 2 (#2D2D2D, dashes of 4), padding 8 / 18 / 8 / 12, the text
    // and the add button 20 apart in the middle; a click opens the picker
    T.Button {
        id: dropBox

        objectName: "playlistChooseFilesButton"
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(186, VLCStyle.scale)
        Accessible.name: qsTr("Choose files")

        leftPadding: VLCStyle.dp(12, VLCStyle.scale)
        rightPadding: VLCStyle.dp(18, VLCStyle.scale)
        topPadding: VLCStyle.dp(8, VLCStyle.scale)
        bottomPadding: VLCStyle.dp(8, VLCStyle.scale)

        background: Rectangle {
            radius: VLCStyle.dp(6, VLCStyle.scale)
            color: VLCStyle.redesign.color("#090909", "#dedede", root.darkTheme)

            Widgets.DashedRect {
                anchors.fill: parent
                lineWidth: VLCStyle.dp(2, VLCStyle.scale)
                corners: false
                fromCorner: true
                color: (dropArea.containsDrag || dropBox.visualFocus)
                       ? VLCStyle.redesign.accent
                       : VLCStyle.redesign.color("#2D2D2D", "#8e8e8d", root.darkTheme)
            }
        }

        contentItem: Item {
            Column {
                // half a pixel down as Figma, on a whole pixel
                width: parent.width
                y: Math.ceil((parent.height - height) / 2)
                spacing: VLCStyle.dp(20, VLCStyle.scale)

                Text {
                    id: dropText

                    // Figma's text box: the advance rounded up, centred
                    // and floored
                    x: Math.floor((parent.width - width) / 2)
                    width: Math.ceil(implicitWidth - 0.05)
                    height: Math.round(1.2109375 * font.pixelSize)
                    text: root.files.length === 0
                          ? qsTr("Drag files into the box or click here to select files.")
                          : qsTr("%1 file selected", "%1 files selected", root.files.length).arg(root.files.length)
                    color: VLCStyle.redesign.color(VLCStyle.redesign.textDisabled, "#7c7c7b", root.darkTheme)
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    verticalAlignment: Text.AlignTop
                    topPadding: VLCStyle.redesign.textBaseline(0, font.pixelSize) - dropMetrics.ascent
                    FontMetrics {
                        id: dropMetrics
                        font: dropText.font
                    }
                }

                AddWrapper {
                    x: Math.floor((parent.width - width) / 2)
                    width: VLCStyle.dp(84, VLCStyle.scale)
                    height: VLCStyle.dp(30, VLCStyle.scale)
                    hovered: dropBox.hovered
                    icon: "half"
                }
            }
        }

        onClicked: root.chooseFiles()

        DropArea {
            id: dropArea

            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                if (!drop.hasUrls)
                    return
                root.files = root.files.concat(drop.urls)
                drop.accept(Qt.CopyAction)
            }
        }
    }
}
