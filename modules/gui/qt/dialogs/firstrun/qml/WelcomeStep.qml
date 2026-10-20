/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic as Controls

import VLC.Style
import VLC.Util

Item {
    id: root
    property var folderUrl
    // the folder as the design writes it ("~/Videos")
    property string folderText: ""
    property bool metadataNetworkAccess: false
    signal browseRequested()
    signal consentRequested(bool allowed)

    // Figma 1899:3055 on whole pixels (centring 1090 gives halves)
    Image {
        width: 141
        height: 141
        x: Math.round((parent.width - width) / 2)
        y: 116
        source: "qrc:///redesign/welcome.svg"
        sourceSize: Qt.size(141, 141)
        fillMode: Image.PreserveAspectFit
        Accessible.name: qsTr("VLC")
    }
    // Figma 1899:3055: the text box (the advance rounded up) centred on the
    // pixel at its left (417)
    Text {
        x: Math.floor((parent.width - width) / 2)
        width: Math.ceil(implicitWidth - 0.05)
        y: 286
        text: qsTr("Welcome to VLC!")
        color: "#eaeaea"
        font.family: VLCStyle.redesign.fontFamily
        font.pixelSize: 32
        font.weight: Font.Light
    }
    Text {
        id: description
        x: Math.round((parent.width - width) / 2)
        y: 362
        width: 595
        wrapMode: Text.WordWrap
        // Figma: lines of 28 (175 %), the glyphs centred on each, the
        // baselines on whole pixels
        lineHeightMode: Text.FixedHeight
        lineHeight: 28
        topPadding: Math.round((28 - 1.2109375 * font.pixelSize) / 2 + 0.96875 * font.pixelSize) - descriptionMetrics.ascent
        text: qsTr("VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols.")
        color: "#969696"
        font.family: VLCStyle.redesign.fontFamily
        font.pixelSize: 16
        font.weight: Font.Light

        FontMetrics {
            id: descriptionMetrics
            font: description.font
        }
    }
    // Figma: a box of 17 (14, line 100 %), the baseline at 514
    Text {
        id: folderLabel
        x: Math.round((parent.width - 595) / 2)
        y: 500
        topPadding: 14 - folderLabelMetrics.ascent
        text: qsTr("Choose a Media Folder to get started with")
        color: "#8f8f8f"
        font.family: VLCStyle.redesign.fontFamily
        font.pixelSize: 14

        FontMetrics {
            id: folderLabelMetrics
            font: folderLabel.font
        }
    }
    Rectangle {
        x: Math.round((parent.width - 595) / 2)
        y: 533
        width: 471
        height: 36
        color: "#090909"
        border.width: 2
        border.color: "#191919"
        radius: 6
        Text {
            id: folderText
            anchors.fill: parent
            // 12 inside the border of 2
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            // the baseline where the design centres a line of Inter
            verticalAlignment: Text.AlignTop
            topPadding: Math.round(height / 2 + VLCStyle.redesign.centeredBaseline(font.pixelSize)) - folderMetrics.ascent
            elide: Text.ElideMiddle
            text: root.folderUrl && root.folderUrl.toString() !== ""
                  ? (root.folderText || Helpers.localPathFromUrl(root.folderUrl)) : qsTr("No folder selected")
            color: "#c6c6c6"
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: 16

            FontMetrics {
                id: folderMetrics
                font: folderText.font
            }
        }
    }
    OnboardingButton {
        x: Math.round((parent.width - 595) / 2) + 481
        // 35 high (padding 8 around 19), centred in the 36 of the row
        y: 533.5
        width: 114
        height: 35
        objectName: "onboardingBrowseFolder"
        text: qsTr("Browse")
        font.weight: Font.Normal
        onClicked: root.browseRequested()
    }
}
