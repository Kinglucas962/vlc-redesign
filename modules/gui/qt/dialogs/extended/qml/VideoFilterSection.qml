/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import VLC.Style
import VLC.Widgets as Widgets

ColumnLayout {
    id: root
    required property var effects
    required property string filterId
    required property string title
    property bool expanded: false
    function c(value) { return VLCStyle.redesign.color(value, value) }
    property var items: []
    spacing: VLCStyle.dp(8, VLCStyle.scale)
    visible: effects.filterAvailable(filterId)

    Component.onCompleted: items = effects.parameters(filterId)

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(4, VLCStyle.scale)
        Text {
            Layout.fillWidth: true
            text: root.title
            color: root.c(VLCStyle.redesign.textPrimary)
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: VLCStyle.dp(15, VLCStyle.scale)
            font.weight: Font.Medium
        }
        // The ON / OFF toggle of the design
        Widgets.CheckButton {
            id: filterToggle
            objectName: "videoFilter-" + root.filterId
            focusPolicy: Qt.StrongFocus
            Accessible.name: qsTr("Enable %1").arg(root.title)
            Binding on checked {
                when: !filterToggle.pressed
                value: { root.effects.revision; return root.effects.filterEnabled(root.filterId) }
            }
            onClicked: root.effects.setFilterEnabled(root.filterId, checked)
        }
    }

    T.Button {
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(48, VLCStyle.scale)
        leftPadding: VLCStyle.dp(16, VLCStyle.scale)
        rightPadding: VLCStyle.dp(16, VLCStyle.scale)
        focusPolicy: Qt.StrongFocus
        Accessible.name: root.expanded ? qsTr("Collapse %1 settings").arg(root.title)
                                       : qsTr("Expand %1 settings").arg(root.title)
        onClicked: root.expanded = !root.expanded
        background: Rectangle { color: root.c("#1B1B1B"); radius: VLCStyle.dp(6, VLCStyle.scale) }
        contentItem: RowLayout {
            Text {
                Layout.fillWidth: true
                text: root.expanded ? qsTr("Collapse Settings") : qsTr("Expand Settings")
                color: root.c(VLCStyle.redesign.textMuted)
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            }
            Image {
                source: root.expanded ? "qrc:///redesign/icons/chevron-down/default.png"
                                      : "qrc:///redesign/icons/chevron-right/default.png"
                sourceSize.width: VLCStyle.dp(16, VLCStyle.scale)
                sourceSize.height: VLCStyle.dp(16, VLCStyle.scale)
                Layout.preferredWidth: sourceSize.width
                Layout.preferredHeight: sourceSize.height
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: settings.implicitHeight + VLCStyle.dp(32, VLCStyle.scale)
        visible: root.expanded
        color: root.c("#1B1B1B")
        radius: VLCStyle.dp(6, VLCStyle.scale)
        ColumnLayout {
            id: settings
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: VLCStyle.dp(16, VLCStyle.scale)
            spacing: VLCStyle.dp(18, VLCStyle.scale)
            Repeater {
                model: root.items
                VideoOption {
                    required property var modelData
                    Layout.fillWidth: true
                    effects: root.effects
                    option: modelData
                }
            }
            T.Button {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Reset")
                onClicked: root.effects.resetDefaults(root.filterId)
                background: Item {}
                contentItem: Text {
                    text: parent.text
                    color: VLCStyle.redesign.accent
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                }
            }
        }
    }
}
