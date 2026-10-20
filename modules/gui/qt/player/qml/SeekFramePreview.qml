/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
import QtQuick
import QtQuick.Window

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// Frame of the playing media at a position of the seek bar, with its time
// (design setting "Show thumbnail while scrubbing").
Rectangle {
    id: root

    // Position of the frame, from 0 to 1
    property real position: 0
    property string timeText
    property bool darkTheme: true

    readonly property real padding: VLCStyle.dp(4, VLCStyle.scale)
    readonly property real frameWidth: VLCStyle.dp(224, VLCStyle.scale)
    // Height of the decoded frames, 16:9 until the first one arrives
    readonly property real frameHeight: frameSource.implicitWidth > 0
        ? Math.round(frameWidth * frameSource.implicitHeight / frameSource.implicitWidth)
        : Math.round(frameWidth * 9 / 16)
    readonly property real _eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

    implicitWidth: frameWidth + 2 * padding
    implicitHeight: frameHeight + label.implicitHeight + 3 * padding + VLCStyle.dp(2, VLCStyle.scale)

    radius: VLCStyle.dp(10, VLCStyle.scale)
    // Menu surface of the design: #191919 at 95%
    color: root.darkTheme ? "#F2191919" : "#F2ABABAA"
    border.width: 1
    border.color: VLCStyle.redesign.color(VLCStyle.redesign.separator, "#9c9c9b", root.darkTheme)

    // Positions are rounded to a thousandth: close hovers share a request
    Image {
        id: frameSource

        visible: false
        asynchronous: true
        // The previous frame stays while the next one decodes
        retainWhileLoading: true
        sourceSize: Qt.size(root.frameWidth * root._eDPR, 0)
        source: root.visible && Player.url.toString() !== ""
                ? VLCThumbnail.preview(Player.url.toString(), root.position) : ""
    }

    Widgets.ImageExt {
        x: root.padding
        y: root.padding
        width: root.frameWidth
        height: root.frameHeight
        radius: VLCStyle.dp(6, VLCStyle.scale)
        backgroundColor: "#0E0E0E"
        fillMode: Image.PreserveAspectCrop
        textureProviderItem: frameSource
    }

    Text {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.padding * 2 + root.frameHeight + VLCStyle.dp(1, VLCStyle.scale)
        text: root.timeText
        color: VLCStyle.redesign.color(VLCStyle.redesign.textPrimary, "#2e2e2e", root.darkTheme)
        font.family: VLCStyle.redesign.fontFamily
        font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
    }
}
