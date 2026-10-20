/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import VLC.Style

ColumnLayout {
    id: root
    required property var effects
    property bool expanded: false
    function c(value) { return VLCStyle.redesign.color(value, value) }
    spacing: VLCStyle.dp(12, VLCStyle.scale)

    T.Button {
        id: accordion
        Layout.fillWidth: true
        implicitHeight: VLCStyle.dp(48, VLCStyle.scale)
        leftPadding: VLCStyle.dp(16, VLCStyle.scale)
        rightPadding: VLCStyle.dp(16, VLCStyle.scale)
        focusPolicy: Qt.StrongFocus
        Accessible.name: root.expanded ? qsTr("Collapse equalizer settings") : qsTr("Expand equalizer settings")
        onClicked: root.expanded = !root.expanded
        background: Rectangle { color: root.c("#1B1B1B"); radius: VLCStyle.dp(6, VLCStyle.scale) }
        contentItem: RowLayout {
            anchors.leftMargin: VLCStyle.dp(16, VLCStyle.scale)
            anchors.rightMargin: VLCStyle.dp(16, VLCStyle.scale)
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
        radius: VLCStyle.dp(6, VLCStyle.scale)
        color: root.c("#1B1B1B")
        visible: root.expanded

        ColumnLayout {
            id: settings
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: VLCStyle.dp(16, VLCStyle.scale)
            spacing: VLCStyle.dp(18, VLCStyle.scale)

            T.Button {
                id: presetButton
                Layout.fillWidth: true
                implicitHeight: VLCStyle.dp(42, VLCStyle.scale)
                leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                rightPadding: VLCStyle.dp(12, VLCStyle.scale)
                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Equalizer preset")
                onClicked: presetsPopup.open()
                background: Rectangle { color: root.c("#0E0E0E"); radius: VLCStyle.dp(5, VLCStyle.scale) }
                contentItem: RowLayout {
                    anchors.leftMargin: VLCStyle.dp(12, VLCStyle.scale)
                    anchors.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.effects.preset) return qsTr("Custom")
                            const match = root.effects.presets.find(p => p.id === root.effects.preset)
                            return match ? match.name : root.effects.preset
                        }
                        color: root.c(VLCStyle.redesign.textSecondary)
                        font.family: VLCStyle.redesign.fontFamily
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    }
                    Image {
                        source: "qrc:///redesign/icons/chevron-down/default.png"
                        sourceSize.width: VLCStyle.dp(16, VLCStyle.scale)
                        sourceSize.height: VLCStyle.dp(16, VLCStyle.scale)
                        Layout.preferredWidth: sourceSize.width
                        Layout.preferredHeight: sourceSize.height
                    }
                }
            }

            ValueSlider {
                Layout.fillWidth: true
                label: qsTr("Preamp")
                unit: qsTr("dB")
                from: -20
                to: 20
                modelValue: root.effects.preamp
                editable: true
                onEdited: (value) => root.effects.setPreamp(value)
            }

            Repeater {
                model: 10
                ValueSlider {
                    required property int index
                    Layout.fillWidth: true
                    readonly property real hz: root.effects.frequencies[index] || 0
                    label: hz >= 1000 ? (hz / 1000).toLocaleString(Qt.locale(), 'f', hz % 1000 ? 1 : 0) + " kHz"
                                      : Math.round(hz) + " Hz"
                    unit: qsTr("dB")
                    from: -20
                    to: 20
                    modelValue: root.effects.bands[index] || 0
                    editable: true
                    onEdited: (value) => root.effects.setBand(index, value)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                T.CheckBox {
                    id: twoPass
                    text: qsTr("Two-pass equalizer")
                    Binding on checked {
                        when: !twoPass.pressed
                        value: root.effects.twoPass
                    }
                    onClicked: root.effects.setTwoPass(checked)
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    indicator: Rectangle {
                        implicitWidth: VLCStyle.dp(18, VLCStyle.scale)
                        implicitHeight: implicitWidth
                        radius: VLCStyle.dp(3, VLCStyle.scale)
                        color: twoPass.checked ? VLCStyle.redesign.accent : root.c("#0E0E0E")
                        border.color: twoPass.checked ? VLCStyle.redesign.accent : root.c(VLCStyle.redesign.border)
                        Image {
                            anchors.centerIn: parent
                            source: "qrc:///redesign/icons/check/selected.png"
                            visible: twoPass.checked
                            sourceSize.width: VLCStyle.dp(14, VLCStyle.scale)
                            sourceSize.height: VLCStyle.dp(14, VLCStyle.scale)
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                T.Button {
                    text: qsTr("Reset")
                    onClicked: root.effects.resetDefaults("equalizer")
                    contentItem: Text {
                        text: parent.text
                        color: VLCStyle.redesign.accent
                        font.family: VLCStyle.redesign.fontFamily
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                    }
                    background: Item {}
                }
            }
        }
    }

    T.Popup {
        id: presetsPopup
        parent: presetButton
        y: presetButton.height + VLCStyle.dp(4, VLCStyle.scale)
        width: presetButton.width
        height: Math.min(VLCStyle.dp(350, VLCStyle.scale), presetList.implicitHeight)
        padding: VLCStyle.dp(8, VLCStyle.scale)
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
        background: Rectangle { color: root.c("#1B1B1B"); radius: VLCStyle.dp(6, VLCStyle.scale) }
        contentItem: ListView {
            id: presetList
            implicitHeight: contentHeight
            clip: true
            model: root.effects.presets
            delegate: T.Button {
                id: presetChoice
                required property var modelData
                width: presetList.width
                height: VLCStyle.dp(38, VLCStyle.scale)
                text: modelData.name
                focusPolicy: Qt.StrongFocus
                onClicked: {
                    if (root.effects.setPreset(modelData.id)) presetsPopup.close()
                }
                background: Rectangle {
                    color: parent.hovered ? root.c(VLCStyle.redesign.controlHoverBackground) : "transparent"
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                }
                contentItem: RowLayout {
                    Text {
                        Layout.fillWidth: true
                        text: presetChoice.text
                        color: root.c(VLCStyle.redesign.textSecondary)
                        font.family: VLCStyle.redesign.fontFamily
                        font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        elide: Text.ElideRight
                    }
                    // Line segments as rotated Rectangles: no Canvas in VLC's Qt Quick.
                    Item {
                        id: curve
                        Layout.preferredWidth: VLCStyle.dp(72, VLCStyle.scale)
                        Layout.preferredHeight: VLCStyle.dp(24, VLCStyle.scale)
                        Accessible.role: Accessible.Graphic
                        Accessible.name: qsTr("%1 equalizer curve").arg(presetChoice.text)

                        readonly property var gains: presetChoice.modelData.bands
                        readonly property bool valid: !!gains && gains.length === 10

                        function pointAt(band) {
                            const gain = Math.max(-20, Math.min(20, Number(gains[band])))
                            return Qt.point(band * width / (gains.length - 1), (20 - gain) * height / 40)
                        }

                        Rectangle {
                            visible: curve.valid
                            y: Math.round(curve.height / 2)
                            width: curve.width
                            height: 1
                            color: root.c(VLCStyle.redesign.border)
                        }

                        Repeater {
                            model: curve.valid ? curve.gains.length - 1 : 0
                            delegate: Rectangle {
                                required property int index
                                readonly property point from: curve.pointAt(index)
                                readonly property point to: curve.pointAt(index + 1)
                                x: from.x
                                y: from.y - height / 2
                                width: Math.hypot(to.x - from.x, to.y - from.y)
                                height: 1.5
                                antialiasing: true
                                transformOrigin: Item.Left
                                rotation: Math.atan2(to.y - from.y, to.x - from.x) * 180 / Math.PI
                                color: VLCStyle.redesign.accent
                            }
                        }
                    }
                    Image {
                        source: "qrc:///redesign/icons/check/selected.png"
                        visible: root.effects.preset === modelData.id
                        sourceSize.width: VLCStyle.dp(18, VLCStyle.scale)
                        sourceSize.height: VLCStyle.dp(18, VLCStyle.scale)
                        Layout.preferredWidth: sourceSize.width
                        Layout.preferredHeight: sourceSize.height
                    }
                }
            }
        }
    }
}
