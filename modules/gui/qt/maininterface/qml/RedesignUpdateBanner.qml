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
import VLC.Style
import VLC.Widgets as Widgets

// A new release of VLC Redesign on GitHub, as a card in the corner of the
// window (the redesign's card colours, 10 px corners): "Update now" for an
// installed copy, "Download" (the release page) for a portable one. After
// "Check for updates" it also says up to date, or why the check failed.
Rectangle {
    id: root

    readonly property bool darkTheme: VLCStyle.palette.isDark
    readonly property int state: RedesignUpdater.state

    visible: RedesignUpdater.showBanner
    width: Math.min(parent.width - 2 * VLCStyle.dp(16, VLCStyle.scale), VLCStyle.dp(420, VLCStyle.scale))
    height: column.implicitHeight + 2 * VLCStyle.dp(16, VLCStyle.scale)
    radius: VLCStyle.dp(10, VLCStyle.scale)
    color: VLCStyle.redesign.color("#191919", "#ABABAA", darkTheme)
    border.width: 1
    border.color: VLCStyle.redesign.color(VLCStyle.redesign.border, "#8f8f8e", darkTheme)

    // the transient results of a manual check go away by themselves
    Timer {
        running: root.visible && root.state === RedesignUpdater.UpToDate
        interval: 4000
        onTriggered: RedesignUpdater.dismiss()
    }

    ColumnLayout {
        id: column
        x: VLCStyle.dp(16, VLCStyle.scale)
        y: VLCStyle.dp(16, VLCStyle.scale)
        width: parent.width - 2 * x
        spacing: VLCStyle.dp(6, VLCStyle.scale)

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: VLCStyle.dp(8, VLCStyle.scale)
                height: width
                radius: width / 2
                color: root.state === RedesignUpdater.Failed ? "#e15033" : VLCStyle.redesign.accent
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: VLCStyle.redesign.color(VLCStyle.redesign.textPrimary, "#1d1d1d", root.darkTheme)
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: VLCStyle.dp(15, VLCStyle.scale)
                font.weight: Font.Medium
                text: {
                    switch (root.state) {
                    case RedesignUpdater.Checking: return qsTr("Checking for updates…")
                    case RedesignUpdater.UpToDate: return qsTr("VLC Redesign %1 is up to date").arg(RedesignUpdater.currentVersion)
                    case RedesignUpdater.Available: return qsTr("VLC Redesign %1 is available").arg(RedesignUpdater.latestVersion)
                    case RedesignUpdater.Downloading: return qsTr("Downloading VLC Redesign %1…").arg(RedesignUpdater.latestVersion)
                    case RedesignUpdater.Failed: return qsTr("Couldn't update")
                    default: return ""
                    }
                }
            }

            // close: a × in the muted text colour, a round hover
            T.Button {
                id: closeButton
                visible: root.state !== RedesignUpdater.Downloading
                implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(24, VLCStyle.scale)
                Accessible.name: qsTr("Close")
                onClicked: RedesignUpdater.dismiss()
                background: Rectangle {
                    radius: width / 2
                    color: closeButton.hovered ? VLCStyle.redesign.color(VLCStyle.redesign.controlHoverBackground, "#9c9c9b", root.darkTheme)
                                               : "transparent"
                }
                contentItem: Text {
                    text: "×"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: VLCStyle.redesign.color(VLCStyle.redesign.textMuted, "#4d4d4d", root.darkTheme)
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            wrapMode: Text.WordWrap
            maximumLineCount: 5
            elide: Text.ElideRight
            color: VLCStyle.redesign.color(VLCStyle.redesign.textSecondary, "#3d3d3d", root.darkTheme)
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
            lineHeight: 1.25
            text: {
                switch (root.state) {
                case RedesignUpdater.Available:
                    return RedesignUpdater.summary.length > 0
                           ? RedesignUpdater.summary.split("\n").map(line => "• " + line).join("\n")
                           : qsTr("You have %1.").arg(RedesignUpdater.currentVersion)
                case RedesignUpdater.Downloading:
                    return qsTr("VLC Redesign will close, update and open again where you were.")
                case RedesignUpdater.Failed:
                    return RedesignUpdater.errorText
                default:
                    return ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: VLCStyle.dp(6, VLCStyle.scale)
            visible: root.state === RedesignUpdater.Available || root.state === RedesignUpdater.Failed
            spacing: VLCStyle.dp(8, VLCStyle.scale)

            Widgets.RedesignButton {
                visible: root.state === RedesignUpdater.Available && !RedesignUpdater.manual
                text: qsTr("Skip")
                onClicked: RedesignUpdater.skipThisVersion()
            }

            Item { Layout.fillWidth: true }

            Widgets.RedesignButton {
                text: root.state === RedesignUpdater.Failed ? qsTr("Retry") : qsTr("What's new")
                onClicked: root.state === RedesignUpdater.Failed ? RedesignUpdater.check(true)
                                                                 : RedesignUpdater.openReleasePage()
            }

            Widgets.RedesignButton {
                accent: true
                text: root.state === RedesignUpdater.Failed ? qsTr("Release page")
                      : RedesignUpdater.canInstall ? qsTr("Update now") : qsTr("Download")
                onClicked: root.state === RedesignUpdater.Failed || !RedesignUpdater.canInstall
                           ? RedesignUpdater.openReleasePage() : RedesignUpdater.install()
            }
        }
    }
}
