/****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * SPDX-License-Identifier: GPL-2.0-or-later
 ****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic
import VLC.Style
import VLC.Util

// Last.fm rows of the Network section of the privacy page of the design
// (they follow "Fetch titles and cover art from the internet")
Column {
    id: root
    property var settingsModel
    property bool available: false
    property bool selected: false

    function px(value) { return VLCStyle.dp(value, VLCStyle.scale) }
    function c(value) { return VLCStyle.redesign.color(value, value) }

    function begin() {
        available = settingsModel && settingsModel.audioscrobblerAvailable()
        if (!available) return
        selected = settingsModel.audioscrobblerEnabled()
        showAll()
    }

    // Figma 3062:11911: the fields are empty while the tracks are not
    // submitted (a field shows its value while it has the focus)
    function show(editor, key) {
        if (editor)
            editor.text = selected || editor.activeFocus ? String(settingsModel.valueFor(key) || "") : ""
    }
    function showAll() {
        show(username, "lastfm-username")
        show(password, "lastfm-password")
        show(submissionUrl, "scrobbler-url")
    }

    component RowLabel: Row {
        property alias text: rowText.text
        property string help
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.px(10)
        Text {
            id: rowText
            // Figma's text box: the advance of Inter 3.19 rounded up (see
            // SettingsOptionRow)
            width: Math.ceil(rowExact.advanceWidth / 16 - text.length * font.pixelSize / 2816 - 0.001)
            anchors.baseline: parent.verticalCenter
            anchors.baselineOffset: VLCStyle.redesign.centeredBaseline(font.pixelSize)
            color: root.c("#8F8F8F")
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: root.px(14)
            TextMetrics {
                id: rowExact
                font.family: rowText.font.family
                font.weight: rowText.font.weight
                font.pixelSize: rowText.font.pixelSize * 16
                text: rowText.text
            }
        }
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: root.px(18)
            height: width
            sourceSize: Qt.size(width, height)
            source: SVGColorImage.colorize("qrc:///redesign/duo/info-small.svg").color1(root.c("#404040")).uri()
            HoverHandler { id: infoHover }
            ToolTip.visible: infoHover.hovered && parent.help.length > 0
            ToolTip.text: parent.help
            ToolTip.delay: 650
        }
    }

    Item {
        width: parent.width
        height: root.px(42)
        visible: root.available
        RowLabel {
            text: qsTr("Submit played tracks to last.fm")
            help: qsTr("Sends the titles of the tracks you play to your Last.fm profile. Takes effect after restarting VLC.")
        }
        SettingsToggle {
            objectName: "settingsLastfmEnabled"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.selected
            onSwitched: (on) => {
                if (root.settingsModel.setAudioscrobblerEnabled(on)) {
                    root.selected = on
                    root.showAll()
                }
            }
            Accessible.name: qsTr("Submit played tracks to last.fm")
        }
    }

    Repeater {
        model: [
            { label: qsTr("Last.fm username"), key: "lastfm-username",
              help: qsTr("The user name of your Last.fm account.") },
            { label: qsTr("Last.fm password"), key: "lastfm-password",
              help: qsTr("The password of your Last.fm account.") },
            { label: qsTr("Last.fm submission URL"), key: "scrobbler-url",
              help: qsTr("The address the played tracks are sent to.") }
        ]
        Item {
            id: fieldRow
            required property var modelData
            width: root.width
            height: root.px(46)
            visible: root.available
            RowLabel {
                text: fieldRow.modelData.label
                help: fieldRow.modelData.help
            }
            SettingsTextField {
                id: editor
                objectName: "settings_" + fieldRow.modelData.key
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(root.px(320), parent.width * 0.46)
                echoMode: fieldRow.modelData.key === "lastfm-password" ? TextInput.Password : TextInput.Normal
                onTextEdited: root.settingsModel.setValue(fieldRow.modelData.key, text)
                onActiveFocusChanged: root.show(editor, fieldRow.modelData.key)
                Accessible.name: fieldRow.modelData.accessible || fieldRow.modelData.label
                Component.onCompleted: {
                    if (fieldRow.modelData.key === "lastfm-username") root.username = editor
                    else if (fieldRow.modelData.key === "lastfm-password") root.password = editor
                    else root.submissionUrl = editor
                }
            }
        }
    }

    property var username
    property var password
    property var submissionUrl
}
