/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Controls.impl as Impl
import QtQuick.Layouts
import QtQml.Models
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Util

FocusScope {
    id: rootPlayer

    // Properties

    //behave like a Page
    property var pagePrefix: []

    readonly property int positionSliderY: controlBar.y + controlBar.sliderY

    readonly property string coverSource: {
        if (Player.artwork &&
            Player.artwork.toString())
            return Player.artwork
        else if (Player.hasVideoOutput)
            return VLCStyle.noArtVideoCover
        else
            return VLCStyle.noArtAlbumCover
    }

    // Only applicable in video mode:
    property bool displayFadeRectangles: !_controlsUnderVideo && (height > (implicitFadeRectangleHeight * 3))
    property real implicitFadeRectangleHeight: VLCStyle.dp(206, VLCStyle.scale)

    // Private

    // Library next to the video (Figma "Player" with the sidebar open)
    property bool libraryVisible: false
    // Created on first use, then kept with its history
    property bool _libraryCreated: false
    onLibraryVisibleChanged: {
        if (libraryVisible)
            _libraryCreated = true
        lockUnlockAutoHide(libraryVisible)
    }

    property bool _controlsUnderVideo: (MainCtx.pinVideoControls
                                        &&
                                        (MainCtx.intfMainWindow.visibility !== Window.FullScreen))

    property bool _keyPressed: false

    // The video is framed between the bars (Figma "Player", Frame 312: a
    // 20 px border of the bar color centred on its edges, radius 19): 10 px
    // of the bar color on its sides (none next to the compact library), 1 px
    // under the top bar, corners of 9 px (19 less half the border)
    // Without the bars (Figma "Player - hide UI") the frame is 10 px on
    // every side
    // In fullscreen the video fills the screen: no frame, no corners
    readonly property bool _fullscreen: MainCtx.intfMainWindow.visibility === Window.FullScreen
    readonly property real _videoInset: (MainCtx.hasEmbededVideo && !_fullscreen) ? VLCStyle.dp(10, VLCStyle.scale) : 0
    readonly property real _videoTopInset: (!MainCtx.hasEmbededVideo || _fullscreen) ? 0
                                           : _controlsUnderVideo ? VLCStyle.dp(1, VLCStyle.scale)
                                                                 : _videoInset
    readonly property real _videoBottomInset: (MainCtx.hasEmbededVideo && !_controlsUnderVideo) ? _videoInset : 0
    readonly property real _videoRadius: VLCStyle.dp(9, VLCStyle.scale)

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Player")
    AccessibleCompat.id: "playerView"

    // Events

    Component.onCompleted: MainCtx.preferHotkeys = true
    Component.onDestruction: MainCtx.preferHotkeys = false

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.accepted)
            return

        _keyPressed = true

        // the keys of the design (onboarding): Q the queue, L the library
        if (event.modifiers === Qt.NoModifier
                && (event.key === Qt.Key_Q || event.key === Qt.Key_L)
                && MainCtx.isHotkeyFree(event.key, event.modifiers)) {
            if (!event.isAutoRepeat) {
                if (event.key === Qt.Key_Q)
                    playlistVisibility.togglePlaylistVisibility()
                else
                    rootPlayer.libraryVisible = !rootPlayer.libraryVisible
            }
            event.accepted = true
            return
        }

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || controlBar.state !== "visible")
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: (event) => {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        rootPlayer.Navigation.defaultKeyReleaseAction(event)
    }

    on_ControlsUnderVideoChanged: {
        lockUnlockAutoHide(_controlsUnderVideo)
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        if (lock) {
            playerToolbarVisibilityFSM.lock()
        } else {
            playerToolbarVisibilityFSM.unlock()
        }
    }

    // Private

    function _onNavigationCancel() {
        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
            MainPlaylistController.stop()
        }

        History.previous()
    }

    //we draw both the view and the window here
    ColorContext {
        id: windowTheme

        // NOTE: We force the night theme when playing a video.
        palette: (MainCtx.hasEmbededVideo && MainCtx.pinVideoControls === false)
                 ? VLCStyle.darkPalette
                 : VLCStyle.palette

        colorSet: ColorContext.Window
    }

    PlayerToolbarVisibilityFSM {
        id: playerToolbarVisibilityFSM

        onForceUnlock:{
            controlBar.forceUnlock()

            topBar.forceUnlock()
        }
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onIsPlaylistVisibleChanged: lockUnlockAutoHide(isPlaylistVisible)
    }

    Connections {
        target: MainCtx

        //playlist
        function onHasEmbededVideoChanged() {
            playlistVisibility.updateVideoEmbed()
            playerToolbarVisibilityFSM.updateVideoEmbed()
        }
        function onAskShow() {
            playerToolbarVisibilityFSM.askShow()
        }
    }


    Connections {
        target: MainCtx.playqueuePanel

        //playlist
        function onDockedChanged() {
            playlistVisibility.updatePlaylistDocked()
        }
        function onVisibleChanged() {
            playlistVisibility.updatePlaylistVisible()
        }
    }


    // Drawn beside the video only: anything over it would hide the video
    // layer, which is under the interface
    // left, right, top, bottom
    Repeater {
        model: rootPlayer._videoInset > 0 ? 4 : 0

        Rectangle {
            required property int index

            x: {
                if (index === 0)
                    return playerSpecializationLoader.x - width
                if (index === 1)
                    return playerSpecializationLoader.x + playerSpecializationLoader.width
                return playerSpecializationLoader.x - rootPlayer._videoInset
            }
            y: index === 3 ? playerSpecializationLoader.y + playerSpecializationLoader.height
                           : playerSpecializationLoader.y - rootPlayer._videoTopInset
            width: {
                if (index >= 2)
                    return playerSpecializationLoader.width + 2 * rootPlayer._videoInset
                return (index === 0 && compactLibrary.visible) ? 0 : rootPlayer._videoInset
            }
            height: {
                if (index === 2)
                    return rootPlayer._videoTopInset
                if (index === 3)
                    return rootPlayer._videoBottomInset
                return playerSpecializationLoader.height + rootPlayer._videoTopInset + rootPlayer._videoBottomInset
            }
            color: VLCStyle.redesign.color(VLCStyle.redesign.playerControlBackground, "#ababaa", VLCStyle.palette.isDark)
        }
    }

    // The rounded corners of the frame of the video (radius 9): the bar color
    // outside the quarter circle, its coverage as Figma draws it
    Repeater {
        model: rootPlayer._videoInset > 0 ? 4 : 0

        // drawn 1:1 (a coloured icon is filtered half a pixel off)
        Image {
            required property int index

            readonly property bool atRight: index === 1 || index === 3
            readonly property bool atBottom: index >= 2

            x: atRight ? playerSpecializationLoader.x + playerSpecializationLoader.width - width
                       : playerSpecializationLoader.x
            y: atBottom ? playerSpecializationLoader.y + playerSpecializationLoader.height - height
                        : playerSpecializationLoader.y
            width: rootPlayer._videoRadius
            height: width
            smooth: false
            source: "qrc:///redesign/player/corner-" + (atBottom ? "b" : "t") + (atRight ? "r" : "l")
                    + (VLCStyle.palette.isDark ? "-dark" : "-light") + ".png"
        }
    }

    Loader {
        id: playerSpecializationLoader

        objectName: "playerSpecializationLoader"

        // Figma 187:328: the library opens over the video, which keeps its
        // place and size (the music moves beside it)
        readonly property bool besideLibrary: compactLibrary.visible && !MainCtx.hasEmbededVideo

        anchors {
            left: besideLibrary ? compactLibrary.right : parent.left
            right: parent.right
            top: (MainCtx.hasEmbededVideo && rootPlayer._controlsUnderVideo) ? topBar.bottom : parent.top
            bottom: (MainCtx.hasEmbededVideo && rootPlayer._controlsUnderVideo) ? controlBar.top : parent.bottom
            leftMargin: besideLibrary ? 0 : rootPlayer._videoInset
            rightMargin: rootPlayer._videoInset
            topMargin: rootPlayer._videoTopInset
            bottomMargin: rootPlayer._videoBottomInset
        }

        sourceComponent: MainCtx.hasEmbededVideo ? videoComponent : audioComponent

        property int cursorShape

        // Have padding here, so that the content (unlike background) does not go behind the top bar or the control bar:
        property real topPadding: (anchors.top === parent.top) ? topBar.height : 0
        property real bottomPadding: (anchors.bottom === parent.bottom) ? controlBar.height : 0


        Component {
            id: videoComponent

            FocusScope {
                // Video

                focus: true

                VideoSurface {
                    id: videoSurface

                    anchors.fill: parent

                    // With regard to `ViewBlockingRectangle`, we
                    // do not need to prevent painting anything
                    // behind because there is already nothing
                    // behind (unlike pip player):
                    renderingEnabled: false

                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                    visible: MainCtx.hasEmbededVideo

                    focus: true

                    cursorShape: playerSpecializationLoader.cursorShape

                    doubleClickEnabled: MainCtx.doubleClickAction !== 0

                    // "Fullscreen controls sensitivity": in fullscreen, the
                    // controls show once the mouse moved that many pixels
                    property point lastMove: Qt.point(-1, -1)
                    function onMouseMove(x, y) {
                        const threshold = MainCtx.fsSensitivity
                        if (MainCtx.intfMainWindow.visibility === Window.FullScreen && threshold > 1
                                && lastMove.x >= 0
                                && Math.max(Math.abs(x - lastMove.x), Math.abs(y - lastMove.y)) < threshold)
                            return
                        lastMove = Qt.point(x, y)
                        onMouseEvent()
                    }

                    function onMouseEvent() {
                        //short interval for mouse events
                        if (Player.isInteractive)
                            interactiveAutoHideTimer.restart()
                        else
                            playerToolbarVisibilityFSM.mouseMove();
                    }

                    Component.onCompleted: {
                        mouseMoved.connect(videoSurface.onMouseMove)
                        mousePressed.connect(videoSurface.onMouseEvent)
                        mouseReleased.connect(videoSurface.onMouseEvent)
                        mouseDblClicked.connect(videoSurface.onMouseEvent)
                    }

                    Binding on cursorShape {
                        when: playerToolbarVisibilityFSM.started
                            && !playerToolbarVisibilityFSM.isVisible
                            && !interactiveAutoHideTimer.running
                        value: Qt.BlankCursor
                    }

                    TouchWheelHandler {

                    }
                }

                component FadeRectangle : Rectangle {
                    implicitHeight: rootPlayer.implicitFadeRectangleHeight

                    SGManipulator {
                        // The rectangle is the bottom-most item in the interface,
                        // it does not need blending even though it is not opaque.
                        // Since `Rectangle` does not provide explicit control over
                        // blending, we are using `SGManipulator`:
                        blending: false
                    }
                }

                FadeRectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: topBar.opacity
                    visible: rootPlayer.displayFadeRectangles && !topBarAcrylicBg.visible

                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                FadeRectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: controlBar.opacity

                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: .64; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "black" }
                    }

                    visible: rootPlayer.displayFadeRectangles && !(controlBar.background && controlBar.background.visible)
                }
            }
        }

        Component {
            id: audioComponent

            MusicView {
                playerRoot: rootPlayer
                topBarItem: topBar
                toggleControlBarItem: toggleControlBarButton
                controlBarItem: controlBar
                topPadding: playerSpecializationLoader.topPadding
                bottomPadding: playerSpecializationLoader.bottomPadding
                coverSource: rootPlayer.coverSource
            }
        }
    }

    TopBar {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 1

        topMargin: VLCStyle.applicationVerticalMargin
        sideMargin: VLCStyle.applicationHorizontalMargin

        textWidth: playlistVisibility.isPlaylistVisible
                 ? rootPlayer.width - playlistpopup.width
                 : rootPlayer.width

        // In fullscreen both bars show on mouse moves and hide again, the
        // title stays reachable (pinned or not).
        focus: true
        title: Player.title
        barIdentifier: controlBar.identifier

        pinControls: MainCtx.pinVideoControls

        showCSD: MainCtx.clientSideDecoration && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        showToolbar: MainCtx.hasToolbarMenu && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        playlistVisible: playlistVisibility.isPlaylistVisible

        plListView: {
            if (playlistpopup.active)
                return playlistpopup.item?.queue ?? null
            else if (playlistWindowLoader?.status === Loader.Ready)
                return playlistWindowLoader.item.playlistView
            else
                return null
        }

        Navigation.parentItem: rootPlayer
        Navigation.downItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            if (Player.isInteractive)
                return toggleControlBarButton
            return controlBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo) ? "visible" : "hidden"
        }

        onTogglePlaylistVisibility: playlistVisibility.togglePlaylistVisibility()

        libraryVisible: rootPlayer.libraryVisible
        libraryActive: rootPlayer.libraryVisible && compactLibrary.item?.location?.section !== "folder"
        onLibraryToggled: rootPlayer.libraryVisible = !rootPlayer.libraryVisible
        onFolderRequested: {
            rootPlayer.libraryVisible = true
            compactLibrary.item.showFolder(compactLibrary.item.folderOf(Player.url))
        }

        onRequestLockUnlockAutoHide: (lock) => {
            rootPlayer.lockUnlockAutoHide(lock)
        }

        onBackRequested: {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
               MainPlaylistController.stop()
            }
            MainCtx.playerView = false
        }

        FadeControllerStateGroup {
            target: topBar
        }

        // TODO: Make TopBar a Control and use background
        Widgets.AcrylicBackground {
            id: topBarAcrylicBg

            z: -1

            anchors.fill: parent

            opacity: {
                if (MainCtx.hasEmbededVideo && !MainCtx.pinVideoControls && !rootPlayer.displayFadeRectangles) {
                    return 0.6
                } else if (MainCtx.intfMainWindow.visibility === Window.FullScreen && MainCtx.hasEmbededVideo) {
                    return MainCtx.pinOpacity
                } else {
                    return 1.0
                }
            }

            tintColor: windowTheme.bg.primary

            visible: MainCtx.pinVideoControls || (MainCtx.hasEmbededVideo && !rootPlayer.displayFadeRectangles)
        }
    }

    Loader {
        id: compactLibrary

        anchors {
            left: parent.left
            top: rootPlayer._controlsUnderVideo ? topBar.bottom : parent.top
            bottom: rootPlayer._controlsUnderVideo ? controlBar.top : parent.bottom
        }

        active: rootPlayer._libraryCreated
        visible: rootPlayer.libraryVisible
        width: item ? item.implicitWidth : 0

        sourceComponent: CompactLibrary {
            onOpenLibraryRequested: (section) => {
                const uris = {
                    home: ["home"], videos: ["video", "all"], music: ["music"], network: ["network"],
                    playlists: ["video", "playlists"], playlist: ["video", "playlists"],
                    recent: ["home", "recent"], folder: ["network"]
                }
                rootPlayer.libraryVisible = false
                MainCtx.playerView = false
                // A folder opens in the folder page of the library
                if (section === "folder" && compactLibrary.item.location.folder)
                    History.push(["folder"], { folderUrl: compactLibrary.item.location.folder })
                else
                    History.push(uris[section] ?? ["home"])
            }
        }
    }

    Loader {
        id: playlistpopup

        anchors {
            // NOTE: When the controls are pinned we display the playqueue under the topBar.
            top: (rootPlayer._controlsUnderVideo) ? topBar.bottom
                                                  : parent.top

            right: parent.right
            bottom: parent.bottom

            bottomMargin: parent.height - rootPlayer.positionSliderY
        }

        focus: false

        active: MainCtx.playqueuePanel.docked

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playlistVisibility.started
            value: (status === Loader.Ready && playlistVisibility.isPlaylistVisible) ? "expanded" : "retracted"
        }

        Component.onCompleted: {
            Qt.callLater(() => { playlistTransition.enabled = true; })
        }

        states: [
            State {
                name: "expanded"
                PropertyChanges {
                    target: playlistpopup
                    width: playlistpopup.implicitWidth
                    visible: true
                }
           }, State {
                name: "retracted"
                PropertyChanges {
                    target: playlistpopup
                    width: 0
                    visible: false
                }
           }
        ]

        transitions: Transition {
            id: playlistTransition
            enabled: false

            from: "retracted"; to: "expanded";
            reversible: true

            SequentialAnimation {
                PropertyAction { property: "visible" }

                NumberAnimation {
                    property: "width"
                    duration: VLCStyle.duration_short
                    easing.type: Easing.InOutSine
                }
            }
        }

        // The card of the design (Figma "Controls / queue"); it keeps its
        // width while the loader grows, anchored to the right edge
        sourceComponent: Item {
            id: queueCardItem

            // The play queue page, for the top bar
            readonly property alias queue: queueCard.queue

            implicitWidth: queueCard.implicitWidth + VLCStyle.dp(20, VLCStyle.scale)
            height: playlistpopup.height
            focus: true

            QueueCard {
                id: queueCard

                anchors {
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom

                    rightMargin: VLCStyle.dp(20, VLCStyle.scale)
                    topMargin: (rootPlayer._controlsUnderVideo ? 0 : topBar.reservedHeight)
                               + VLCStyle.dp(20, VLCStyle.scale)
                    // The loader ends at the slider, within the control bar
                    bottomMargin: (rootPlayer.positionSliderY - controlBar.y) + VLCStyle.dp(20, VLCStyle.scale)
                }
                width: implicitWidth
                focus: true

                Navigation.parentItem: rootPlayer
                Navigation.upItem: topBar
                Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
                Navigation.leftAction: closeQueue
                Navigation.cancelAction: closeQueue

                function closeQueue() {
                    playlistVisibility.togglePlaylistVisibility()
                    if (audioControls.visible)
                        audioControls.forceActiveFocus()
                    else
                        controlBar.forceActiveFocus()
                }
            }
        }
    }

    Dialogs {
        z: 10
        bgContent: rootPlayer

        anchors {
            bottom: controlBar.visible ? controlBar.top : rootPlayer.bottom
            left: parent.left
            right: parent.right

            bottomMargin: (rootPlayer._controlsUnderVideo || !controlBar.visible)
                          ? 0 : - VLCStyle.margin_large
        }
    }

    Timer {
        // NavigationBox's visibility depends on this timer
        id: interactiveAutoHideTimer
        running: false
        repeat: false
        interval: 3000
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && navBox.show
                    && (interactiveAutoHideTimer.running
                    || navBox.hovered || !MainCtx.hasEmbededVideo)

        x: rootPlayer.x + VLCStyle.margin_normal + VLCStyle.applicationHorizontalMargin
        y: controlBar.y - navBox.height - VLCStyle.margin_normal

        dragXMin: 0
        dragXMax: rootPlayer.width - navBox.width
        dragYMin: 0
        dragYMax: rootPlayer.height - navBox.height

        Drag.onDragStarted: (controlId) => {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    Connections {
        target: MainCtx
        function onNavBoxToggled() { interactiveAutoHideTimer.restart() }
    }

    Connections {
        target: rootPlayer
        function onWidthChanged() {
            if (navBox.x > navBox.dragXMax)
                navBox.x = navBox.dragXMax
        }
        function onHeightChanged() {
            if (navBox.y > navBox.dragYMax)
                navBox.y = navBox.dragYMax
        }
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && MainCtx.hasEmbededVideo
                 && !(MainCtx.pinVideoControls && !Player.fullscreen)
                 && (interactiveAutoHideTimer.running === true
                     || controlBar.state !== "hidden" || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: controlBar.state === "hidden" ? parent.bottom : controlBar.top
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: controlBar.state === "hidden" ? VLCIcons.expand_inverted : VLCIcons.expand

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : topBar)
        Navigation.downItem: controlBar

        onClicked:{
            playerToolbarVisibilityFSM.askShow();
        }
    }

    Widgets.FloatingNotification {
        id: notif

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    ControlBar {
        id: controlBar

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        hoverEnabled: true

        focus: true

        rightPadding: VLCStyle.applicationHorizontalMargin
        leftPadding: VLCStyle.applicationHorizontalMargin
        bottomPadding: VLCStyle.applicationVerticalMargin + VLCStyle.margin_xsmall

        textPosition: (MainCtx.pinVideoControls)
                      ? ControlBar.TimeTextPosition.LeftRightSlider
                      : ControlBar.TimeTextPosition.AboveSlider

        // hide right text so that it won't overlap with play queue
        showRemainingTime: (textPosition !== ControlBar.TimeTextPosition.AboveSlider)
                           || !playlistVisibility.isPlaylistVisible

        onStateChanged: {
            if (state === "visible")
                showChapterMarks()
        }

        Navigation.parentItem: rootPlayer
        Navigation.upItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (Player.isInteractive)
                return toggleControlBarButton
            if (!MainCtx.hasEmbededVideo)
                return playerSpecializationLoader
            return topBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: (playerToolbarVisibilityFSM.isVisible || rootPlayer._controlsUnderVideo) ? "visible" : "hidden"
        }

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                            : PlayerControlbarModel.Audioplayer

        onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)

        background: Rectangle {
            id: controlBarBackground

            visible: !MainCtx.hasEmbededVideo || MainCtx.pinVideoControls || !rootPlayer.displayFadeRectangles

            opacity: {
                if (MainCtx.hasEmbededVideo && !MainCtx.pinVideoControls && !rootPlayer.displayFadeRectangles) {
                    return 0.6
                } else if ((Window.visibility === Window.FullScreen) && MainCtx.hasEmbededVideo) {
                    return MainCtx.pinOpacity
                } else if (AcrylicController.enabled || !MainCtx.hasEmbededVideo) {
                    return 0.7
                } else {
                    return 1.0
                }
            }

            color: windowTheme.bg.primary
        }

        FadeControllerStateGroup {
            target: controlBar
        }
    }

    // Next to the play button, where it is seen in the seconds it stays
    ResumeDialog {
        id: resumeDialog

        anchors.left: controlBar.left
        anchors.bottom: controlBar.top
        anchors.leftMargin: VLCStyle.dp(16, VLCStyle.scale) + rootPlayer._videoInset
        anchors.bottomMargin: VLCStyle.dp(12, VLCStyle.scale)
        width: Math.min(implicitWidth, rootPlayer.width - anchors.leftMargin * 2)
        height: implicitHeight
        z: 2

        Navigation.parentItem: rootPlayer
        Navigation.downItem: controlBar

        onHidden: {
            if (activeFocus)
                controlBar.forceActiveFocus()
        }

        // The controls stay shown while it is
        onVisibleChanged: rootPlayer.lockUnlockAutoHide(visible)
    }

    QmlAudioContextMenu {
        id: audioContextMenu

        ctx: MainCtx
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !MainCtx.hasEmbededVideo

        onTapped: (eventPoint, button) => {
            if (button & Qt.RightButton) {
                audioContextMenu.popup(eventPoint.globalPosition)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        propagateComposedEvents: true
        cursorShape: undefined
        onClicked: {
            MainCtx.playerView = false
        }
    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
    id: filter
    target: MainCtx.intfMainWindow

        Keys.onPressed: (event) => {
            if (Player.isInteractive)
                interactiveAutoHideTimer.restart()
            else
                playerToolbarVisibilityFSM.keyboardMove()
        }
    }
}
