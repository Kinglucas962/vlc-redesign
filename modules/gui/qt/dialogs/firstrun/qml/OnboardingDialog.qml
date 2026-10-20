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

import VLC.Dialogs as Dialogs
import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Controls.Popup {
    id: root
    objectName: "onboardingDialog"
    modal: true
    focus: true
    padding: 0
    // Escape closes it, except while the folder is added to the media library
    closePolicy: controller.busy ? Controls.Popup.NoAutoClose : Controls.Popup.CloseOnEscape
    // centred on whole pixels: the text stays crisp
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0
    width: Math.min(1090, parent ? parent.width - 24 : 1090)
    height: Math.min(759, parent ? parent.height - 24 : 759)

    property int step: 0
    property var folderUrl
    property bool metadataNetworkAccess: false
    property color initialAccent: "#d37918"
    property color selectedAccent: "#d37918"
    property bool previousGlobalShortcuts: true
    property bool committed: false
    property bool skipping: false
    property var shortcuts: []

    Dialogs.OnboardingController {
        id: controller
        ctx: MainCtx
        onCompleted: {
            if (!root.skipping)
                MainCtx.setSettingValue("redesign/accent", root.selectedAccent.toString())
            root.committed = true
            root.close()
        }
    }
    Widgets.FilePicker { id: filePicker; ctx: MainCtx }

    onOpened: {
        committed = false
        skipping = false
        step = 0
        initialAccent = VLCStyle.redesign.accent
        selectedAccent = initialAccent
        folderUrl = controller.suggestedFolder
        metadataNetworkAccess = controller.needsSetup ? false : controller.metadataNetworkAccess
        shortcuts = controller.activeShortcuts()
        previousGlobalShortcuts = MainCtx.useGlobalShortcuts
        MainCtx.useGlobalShortcuts = false
        controller.begin()
    }
    onClosed: {
        if (!committed) {
            controller.cancel()
            VLCStyle.redesign.accent = initialAccent
        }
        MainCtx.useGlobalShortcuts = previousGlobalShortcuts
    }
    background: Rectangle {
        radius: 14
        color: "#0e0e0e"
        border.color: "#222222"
    }

    contentItem: Item {
        Item {
            id: stage
            width: 1090
            height: 759
            anchors.centerIn: parent
            scale: Math.min(root.width / width, root.height / height)

            WelcomeStep {
                anchors.fill: parent
                visible: root.step === 0
                folderUrl: root.folderUrl
                folderText: controller.displayPath(root.folderUrl)
                metadataNetworkAccess: root.metadataNetworkAccess
                onConsentRequested: allowed => root.metadataNetworkAccess = allowed
                onBrowseRequested: {
                    const chosen = filePicker.chooseFolder(qsTr("Choose a media folder"))
                    if (chosen.toString() !== "")
                        root.folderUrl = chosen
                }
            }
            ThemeStep {
                anchors.fill: parent
                visible: root.step === 1
                themeIndex: controller.themeIndex
                accent: root.selectedAccent
                onThemeRequested: index => controller.previewTheme(index)
                onAccentRequested: colorValue => {
                    root.selectedAccent = colorValue
                    VLCStyle.redesign.accent = colorValue
                }
            }
            ShortcutsStep {
                anchors.fill: parent
                visible: root.step === 2
                shortcuts: root.shortcuts
            }

            Text {
                x: 62
                y: 628
                width: parent.width - 124
                visible: controller.error !== ""
                text: controller.error
                color: "#e57373"
                wrapMode: Text.WordWrap
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: 14
            }

            OnboardingButton {
                x: 62
                y: 671
                // Figma: no Skip on the first run; Cancel when reopened
                visible: root.step === 0 && !controller.needsSetup
                text: qsTr("Cancel")
                objectName: "onboardingSkipButton"
                enabled: !controller.busy
                onClicked: {
                    if (!controller.needsSetup) {
                        root.close()
                        return
                    }
                    root.skipping = true
                    root.selectedAccent = root.initialAccent
                    VLCStyle.redesign.accent = root.initialAccent
                    controller.skip()
                }
            }
            // Figma 1902:6770: Back 8 before Finish
            OnboardingButton {
                x: 820
                y: 671
                visible: root.step > 0
                text: qsTr("Back")
                objectName: "onboardingBackButton"
                enabled: !controller.busy
                onClicked: --root.step
            }
            OnboardingButton {
                x: 928
                y: 671
                primary: true
                text: root.step === 2 ? qsTr("Finish") : qsTr("Next")
                objectName: "onboardingNextButton"
                enabled: !controller.busy
                onClicked: {
                    if (root.step < 2) {
                        ++root.step
                        return
                    }
                    const selected = root.folderUrl && root.folderUrl.toString() !== ""
                                     ? [root.folderUrl] : []
                    controller.finish(selected, root.metadataNetworkAccess)
                }
            }
        }
    }

    // Keeps the title bar draggable while this modal dialog is open
    Widgets.CSDModalDragStrip { dialog: root }
}
