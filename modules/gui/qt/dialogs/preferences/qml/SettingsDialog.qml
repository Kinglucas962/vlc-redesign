/****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * SPDX-License-Identifier: GPL-2.0-or-later
 ****************************************************************************/
import QtQuick
import QtQuick.Controls.Basic
import VLC.Dialogs
import VLC.MainInterface
import VLC.Style
import VLC.Util
import VLC.Widgets as Widgets

// Settings of the design (Figma "Settings - *", 1048 x 865): the 50 px header
// (search, page title, close), the 200 px sidebar in an 8 px margin, and the
// page (24 px sides, 20 px top, 20 px between sections). No footer: the
// changes are kept when the dialog closes.
Dialog {
    id: root
    objectName: "redesignSettingsDialog"
    modal: true
    focus: true
    padding: 0
    topPadding: 0
    bottomPadding: 0
    closePolicy: Popup.CloseOnEscape
    width: Math.min(px(1048), parent ? parent.width - px(32) : px(1048))
    height: Math.min(px(865), parent ? parent.height - px(32) : px(865))
    // Centred on whole pixels: at half a pixel every edge and text blurs
    x: Math.round(((parent ? parent.width : width) - width) / 2)
    y: Math.round(((parent ? parent.height : height) - height) / 2)
    header: null
    footer: null

    property string selectedCategory: "general"
    property bool saved: false
    property bool previousGlobalShortcuts: true
    property bool advancedExpanded: false
    // Advanced Options start closed on every page
    onSelectedCategoryChanged: advancedExpanded = false
    readonly property bool dark: VLCStyle.palette.isDark

    function px(value) { return VLCStyle.dp(value, VLCStyle.scale) }
    function c(value) { return VLCStyle.redesign.color(value, value) }

    // Titles of the pages in the design
    readonly property var titles: ({
        extensions: qsTr("Add-ons & Scripts"),
        general: qsTr("Global Settings"), interface: qsTr("Interface Settings"),
        privacy: qsTr("Privacy Settings"), controls: qsTr("Mouse, Keyboard & Remote Controls"),
        playback: qsTr("Playback Preferences"), video: qsTr("Video Defaults"),
        audio: qsTr("Audio Defaults"), subtitles: qsTr("Subtitle Defaults"),
        library: qsTr("Playlists, Folders & Files"), network: qsTr("Network Connections & Security"),
        performance: qsTr("Performance Settings"), recording: qsTr("Recording, Casting & Streaming Out")
    })

    function openSettings(category) {
        selectedCategory = category || "general"
        searchField.text = ""
        open()
    }

    // Keeps every change (the design has no Apply button)
    function commit() {
        if (saved)
            return
        saved = true
        const audioOutputReady = audioOutput.canApply()
        if (config.applyWithEffects(inlineEffects.audioForSave(), inlineEffects.videoForSave())) {
            if (audioOutputReady)
                audioOutput.apply()
        }
        inlineEffects.clearDirty()
        appearance.save()
        developerMode.save()
        MainCtx.controlbarProfileModel.save()
    }

    onOpened: {
        saved = false
        previousGlobalShortcuts = MainCtx.useGlobalShortcuts
        MainCtx.useGlobalShortcuts = false
        config.reload()
        appearance.begin()
        developerMode.begin()
        lastfm.begin()
        advancedExpanded = false
        inlineEffects.beginForCurrentCategory()
    }
    onClosed: {
        commit()
        inlineEffects.cancel()
        audioOutput.cancel()
        MainCtx.useGlobalShortcuts = previousGlobalShortcuts
    }
    ShortcutsDialog { id: shortcutsDialog; parent: root.parent }

    ConfigModel {
        id: config
        ctx: MainCtx
        category: searchField.text.length > 0 ? "" : root.selectedCategory
        search: searchField.text
    }

    // #0E0E0E at 95 %, radius 14 (Dark/BG/B1 Transparent)
    background: Rectangle {
        radius: root.px(14)
        // 95 % over a 50 px blur in the design: solid where nothing shows through
        color: root.c("#0E0E0E")
    }

    contentItem: Item {
        // Header: #090909, 50 px, search at 8 px, title at 240 px, close at 14 px
        Rectangle {
            id: topbar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.px(50)
            radius: root.px(14)
            color: root.c("#090909")
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: root.px(8)
                anchors.verticalCenter: parent.verticalCenter
                width: root.px(200)
                height: root.px(34)
                radius: root.px(6)
                color: root.c("#151515")

                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: root.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.px(24)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: SVGColorImage.colorize("qrc:///redesign/search.svg")
                                         .any({ "#6B6B6B": root.c("#6B6B6B") }).uri()
                }
                TextField {
                    id: searchField
                    objectName: "settingsSearch"
                    anchors.fill: parent
                    leftPadding: root.px(8 + 24 + 10)
                    rightPadding: root.px(8)
                    placeholderText: qsTr("Search")
                    placeholderTextColor: root.c("#404040")
                    // Figma's baseline: the 17 px line centred in the 34
                    // (8.5), the baseline 14 px under its top (measured)
                    verticalAlignment: TextInput.AlignTop
                    topPadding: (height - Math.round(1.2109375 * font.pixelSize)) / 2
                                + Math.round(VLCStyle.redesign.textBaseline(0, font.pixelSize)) - searchMetrics.ascent
                    bottomPadding: 0
                    FontMetrics { id: searchMetrics; font: searchField.font }
                    color: root.c("#8F8F8F")
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: root.px(14)
                    background: Item {}
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: root.px(240)
                // the design centres its 19 px line at 15.5 px (not rounded)
                // and draws the baseline 15 px under it (measured)
                anchors.baseline: parent.top
                anchors.baselineOffset: (parent.height - Math.round(1.2109375 * font.pixelSize)) / 2
                                        + Math.round(VLCStyle.redesign.textBaseline(0, font.pixelSize))
                anchors.right: closeButton.left
                elide: Text.ElideRight
                text: searchField.text.length > 0 ? qsTr("Search results")
                      : root.titles[root.selectedCategory] || qsTr("Settings")
                color: root.c("#969696")
                font.family: VLCStyle.redesign.fontFamily
                font.pixelSize: root.px(16)
            }
            // The Icon component of the design: 32 x 32 around the 12 px cross
            Button {
                id: closeButton
                objectName: "settingsClose"
                anchors.right: parent.right
                anchors.rightMargin: root.px(14)
                anchors.verticalCenter: parent.verticalCenter
                width: root.px(32)
                height: width
                padding: root.px(4)
                // the Basic style adds 2 px to the sides otherwise
                horizontalPadding: root.px(4)
                onClicked: root.close()
                Accessible.name: qsTr("Close")
                background: Rectangle {
                    radius: root.px(4)
                    color: closeButton.hovered ? root.c("#191919") : "transparent"
                    border.width: closeButton.visualFocus ? 1 : 0
                    border.color: VLCStyle.redesign.accent
                }
                contentItem: Image {
                    width: root.px(24)
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: SVGColorImage.colorize("qrc:///redesign/duo/close.svg").color1(root.c("#8F8F8F")).uri()
                }
            }
        }

        // The page column of the design is #0F0F0F (the sidebar column stays
        // #0E0E0E); the rounded corner of the dialog at the bottom right
        Item {
            x: root.px(216)
            y: root.px(50)
            width: parent.width - x
            height: parent.height - y
            clip: true
            Rectangle {
                x: -parent.x
                y: -parent.y
                width: root.width
                height: root.height
                radius: root.px(14)
                color: root.c("#0F0F0F")
            }
        }

        SettingsSidebar {
            id: sidebar
            objectName: "settingsSidebar"
            anchors.left: parent.left
            anchors.leftMargin: root.px(8)
            anchors.top: topbar.bottom
            anchors.topMargin: root.px(8)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.px(8)
            width: root.px(200)
            category: root.selectedCategory
            availableCategories: config.categories
            onSelected: (category) => {
                root.selectedCategory = category
                searchField.text = ""
                contentFlick.contentY = -contentFlick.topMargin
                root.advancedExpanded = false
                inlineEffects.beginForCurrentCategory()
            }
        }

        Flickable {
            id: contentFlick
            objectName: "settingsContent"
            anchors.left: parent.left
            anchors.leftMargin: root.px(216 + 24)
            anchors.right: parent.right
            anchors.rightMargin: root.px(24)
            anchors.top: topbar.bottom
            anchors.bottom: parent.bottom
            topMargin: root.px(20)
            bottomMargin: root.px(100)
            contentHeight: contentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                parent: contentFlick.parent
                anchors.top: contentFlick.top
                anchors.bottom: contentFlick.bottom
                anchors.right: parent.right
                anchors.rightMargin: root.px(4)
                policy: ScrollBar.AsNeeded
            }

            Column {
                id: contentColumn
                width: contentFlick.width
                spacing: root.px(20)

                SettingsAppearance {
                    id: appearance
                    width: parent.width
                    visible: root.selectedCategory === "general"
                             && (searchField.text.length === 0
                                 || qsTr("appearance theme accent language").toLowerCase()
                                       .includes(searchField.text.toLowerCase()))
                }

                SettingsSectionTitle {
                    visible: root.selectedCategory === "controls" && !searchField.text.length
                    text: qsTr("Keyboard Shortcuts")

                    SettingsActionRow {
                        label: qsTr("Defaults")
                        buttonText: qsTr("Edit Keyboard Shortcuts")
                        onClicked: shortcutsDialog.open()
                    }
                    SettingsActionRow {
                        label: qsTr("Reset all shortcuts")
                        buttonText: qsTr("Reset")
                        onClicked: shortcutsDialog.openReset()
                    }
                }

                SettingsExtensions {
                    id: extensions
                    width: parent.width
                    visible: root.selectedCategory === "extensions" && !searchField.text.length
                    settingsModel: config
                }
                // The Last.fm rows continue the Network section of the privacy page
                Column {
                    width: parent.width
                    // Not the visible of the children: it depends on this one
                    visible: !extensions.visible

                    SettingsOptionList {
                        id: optionList
                        visible: !extensions.visible
                        width: parent.width
                        settingsModel: config
                        category: root.selectedCategory
                        search: searchField.text
                        filterMode: searchField.text.length ? "all" : "basic"
                        sectionFilter: root.selectedCategory === "video" && !searchField.text.length
                                       ? qsTr("Output")
                                       : root.selectedCategory === "general" && !searchField.text.length
                                         ? qsTr("Startup") : ""
                    }

                    SettingsLastfm {
                        id: lastfm
                        width: parent.width
                        settingsModel: config
                        visible: (!searchField.text.length && root.selectedCategory === "privacy")
                                 || (searchField.text.length > 0
                                     && qsTr("last.fm lastfm username password scrobbler")
                                        .includes(searchField.text.toLowerCase()))
                    }
                }

                Column {
                    width: parent.width
                    visible: root.selectedCategory === "general"
                             && (!searchField.text.length
                                 || qsTr("developer mode diagnostics")
                                    .includes(searchField.text.toLowerCase()))
                    SettingsDeveloperMode {
                        id: developerMode
                        width: parent.width
                    }
                    SettingsOptionList {
                        id: generalMoreOptions
                        width: parent.width
                        visible: !searchField.text.length
                        settingsModel: config
                        category: root.selectedCategory
                        filterMode: "basic"
                        excludedSection: qsTr("Startup")
                        hideSectionHeadings: true
                    }
                }

                // The device of the playing output (its default is the
                // "Output device" option of the list)
                SettingsAudioOutput {
                    id: audioOutput
                    width: parent.width
                    visible: false
                }

                SettingsInlineEffects {
                    id: inlineEffects
                    width: parent.width
                    category: root.selectedCategory
                    searchActive: searchField.text.length > 0
                }

                SettingsOptionList {
                    id: videoMoreOptions
                    width: parent.width
                    visible: root.selectedCategory === "video" && !searchField.text.length
                    settingsModel: config
                    category: root.selectedCategory
                    filterMode: "basic"
                    excludedSection: qsTr("Output")
                }

                Text {
                    visible: optionList.availableCount === 0 && !appearance.visible
                             && !developerMode.visible
                             && !lastfm.visible
                             && !inlineEffects.visible && !extensions.visible
                    text: searchField.text.length > 0
                          ? qsTr("No matching settings")
                          : qsTr("No settings are available for this category on this VLC installation")
                    color: root.c("#6B6B6B")
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: root.px(14)
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                // Advanced Options of the design: 38 px, #191919 at 95 %, radius 2
                Button {
                    id: advancedButton
                    objectName: "settingsAdvancedOptions"
                    // Every page of the design ends with it, but Privacy
                    visible: !searchField.text.length && root.selectedCategory !== "privacy"
                    width: parent.width
                    height: root.px(38)
                    onClicked: root.advancedExpanded = !root.advancedExpanded
                    Accessible.name: qsTr("Advanced Options")
                    background: Rectangle {
                        radius: root.px(2)
                        color: root.dark ? Qt.rgba(25 / 255, 25 / 255, 25 / 255, 0.95) : root.c("#191919")
                        border.width: advancedButton.visualFocus ? 1 : 0
                        border.color: VLCStyle.redesign.accent
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: root.px(10)
                            Text {
                                anchors.baseline: parent.verticalCenter
                                anchors.baselineOffset: VLCStyle.redesign.centeredBaseline(font.pixelSize)
                                text: qsTr("Advanced Options")
                                color: root.c("#8F8F8F")
                                font.family: VLCStyle.redesign.fontFamily
                                font.pixelSize: root.px(14)
                            }
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.px(24)
                                height: width
                                sourceSize: Qt.size(width, height)
                                source: root.advancedExpanded ? "qrc:///redesign/icons/chevron-down/default.png"
                                                              : "qrc:///redesign/icons/chevron-right/default.png"
                            }
                        }
                    }
                }

                SettingsOptionList {
                    id: advancedOptions
                    width: parent.width
                    visible: advancedButton.visible && root.advancedExpanded
                    onResetAllRequested: confirmReset.open()
                    settingsModel: config
                    category: root.selectedCategory
                    filterMode: "advanced"
                }


                // Advanced Options of the add-ons
                Column {
                    width: parent.width
                    visible: advancedButton.visible && root.advancedExpanded
                             && root.selectedCategory === "extensions"
                    Item {
                        width: parent.width
                        height: root.px(42)
                        Text {
                            anchors.left: parent.left
                            anchors.baseline: parent.verticalCenter
                            anchors.baselineOffset: VLCStyle.redesign.centeredBaseline(font.pixelSize)
                            text: qsTr("Show installed add-ons only")
                            color: root.c("#8F8F8F")
                            font.family: VLCStyle.redesign.fontFamily
                            font.pixelSize: root.px(14)
                        }
                        SettingsToggle {
                            objectName: "settingsInstalledOnly"
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            checked: extensions.installedOnly
                            onSwitched: (on) => extensions.installedOnly = on
                            Accessible.name: qsTr("Show installed add-ons only")
                        }
                    }
                    SettingsActionRow {
                        width: parent.width
                        label: qsTr("Plugins and extensions")
                        buttonText: qsTr("Open")
                        onClicked: DialogsProvider.pluginDialog()
                    }
                }

                Text {
                    visible: advancedButton.visible && root.advancedExpanded
                             && root.selectedCategory !== "general" && root.selectedCategory !== "extensions"
                             && advancedOptions.availableCount === 0
                    width: parent.width
                    text: qsTr("No advanced options on this page.")
                    color: root.c("#6B6B6B")
                    font.family: VLCStyle.redesign.fontFamily
                    font.pixelSize: root.px(14)
                }

                SettingsActionRow {
                    visible: advancedButton.visible && root.advancedExpanded
                             && root.selectedCategory === "general"
                    width: parent.width
                    label: qsTr("Welcome setup")
                    buttonText: qsTr("Open")
                    onClicked: { root.close(); DialogsProvider.firstRunDialog() }
                }
            }
        }
    }

    Dialog {
        id: confirmReset
        objectName: "confirmResetAllSettings"
        parent: root.parent
        x: Math.round(((parent ? parent.width : width) - width) / 2)
        y: Math.round(((parent ? parent.height : height) - height) / 2)
        width: root.px(420)
        modal: true
        title: qsTr("Reset all settings?")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            config.resetAll()
            // nothing staged to keep: the settings are the defaults now
            root.saved = true
            root.close()
        }
        contentItem: Text {
            text: qsTr("Every setting of VLC media player goes back to its default.")
            wrapMode: Text.WordWrap
            color: root.c("#8F8F8F")
            font.family: VLCStyle.redesign.fontFamily
            font.pixelSize: root.px(14)
        }
    }

    // Keeps the title bar draggable while this modal dialog is open
    Widgets.CSDModalDragStrip { dialog: root }
}
