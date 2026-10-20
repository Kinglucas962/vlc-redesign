/****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * SPDX-License-Identifier: GPL-2.0-or-later
 ****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic
import VLC.MainInterface
import VLC.Style
import VLC.Util

// Diagnostics section of the design: Developer mode first (the rows of the
// log follow in the page)
SettingsSectionTitle {
    id: root
    text: qsTr("Diagnostics")

    property bool selected: false
    property bool initial: false
    readonly property bool dirty: selected !== initial

    function begin() {
        // the ini gives "true" / "false" back as text ("false" is truthy)
        const value = MainCtx.settingValue("redesign/developer-mode", false)
        initial = value === true || String(value) === "true"
        selected = initial
    }
    function cancel() { selected = initial }
    function resetDefaults() { selected = false }
    function save() {
        MainCtx.setSettingValue("redesign/developer-mode", selected)
        initial = selected
    }
    function c(value) { return VLCStyle.redesign.color(value, value) }

    Item {
        width: parent.width
        height: root.px(42)

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(10)
            Text {
                anchors.baseline: parent.verticalCenter
                anchors.baselineOffset: VLCStyle.redesign.centeredBaseline(font.pixelSize)
                text: qsTr("Developer mode")
                color: root.c("#8F8F8F")
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: root.px(14)
            }
            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: root.px(18)
                height: width
                sourceSize: Qt.size(width, height)
                source: SVGColorImage.colorize("qrc:///redesign/duo/info-small.svg").color1(root.c("#404040")).uri()
                HoverHandler { id: developerHelpHover }
                ToolTip.visible: developerHelpHover.hovered
                ToolTip.text: qsTr("Shows the advanced options of diagnostics and logging.")
                ToolTip.delay: 650
            }
        }

        SettingsToggle {
            objectName: "settingsDeveloperMode"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.selected
            onSwitched: (on) => root.selected = on
            Accessible.name: qsTr("Developer mode")
        }
    }
}
