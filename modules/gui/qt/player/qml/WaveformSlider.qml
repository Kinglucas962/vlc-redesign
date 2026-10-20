/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 or later.
 *****************************************************************************/
import QtQuick
import VLC.Player
import VLC.Style

SliderBar {
    id: root
    objectName: "waveformSlider"
    redesign: true
    barHeight: VLCStyle.redesign.seekHeight

    Waveform {
        id: analysis
        source: Player.videoTracks.count === 0 ? Player.url : ""
        durationSeconds: Player.length.toSeconds()
    }

    // Built from Rectangles: VLC's Qt Quick is compiled without Canvas.
    // Over the bar of SliderBar: the track of the design with the waveform
    // in it (no fill: the played bars show the progress) and the handle; the
    // pointer handlers below still get the events
    Rectangle {
        id: graph
        anchors.fill: parent
        z: 1
        visible: analysis.ready && peaks.length > 0
        radius: VLCStyle.redesign.controlRadius
        color: VLCStyle.redesign.color(VLCStyle.redesign.seekBackground, "#dedede")
        readonly property real played: Math.max(0, Math.min(1, Number(Player.position)))
        readonly property real inset: VLCStyle.dp(6, VLCStyle.scale)
        readonly property real pitch: VLCStyle.dp(5, VLCStyle.scale)
        readonly property real barWidth: VLCStyle.dp(2, VLCStyle.scale)
        readonly property real maxHeight: height - VLCStyle.dp(2, VLCStyle.scale)
        // Relative peak (0..1) of each bar, from the 512 analysis bins
        readonly property var peaks: {
            const bins = analysis.bins
            if (!analysis.ready || width <= 0 || bins.length !== 512)
                return []
            const columns = Math.max(1, Math.min(512, Math.floor((width - 2 * inset + pitch - barWidth) / pitch)))
            let largest = 0
            for (let i = 0; i < bins.length; ++i)
                largest = Math.max(largest, Number(bins[i]))
            const scale = Math.max(largest, 0.05)
            const result = []
            for (let column = 0; column < columns; ++column) {
                const first = Math.floor(column * bins.length / columns)
                const last = Math.max(first + 1, Math.floor((column + 1) * bins.length / columns))
                let peak = 0
                for (let bin = first; bin < last; ++bin)
                    peak = Math.max(peak, Number(bins[bin]))
                result.push(peak / scale)
            }
            return result
        }
        Repeater {
            model: graph.peaks.length
            delegate: Rectangle {
                required property int index
                readonly property real peak: graph.peaks[index]
                x: graph.inset + index * graph.pitch
                width: graph.barWidth
                height: Math.max(graph.barWidth, Math.round(peak * graph.maxHeight))
                y: (graph.height - height) / 2
                radius: width / 2
                readonly property bool isPlayed: (x + width / 2) / graph.width <= graph.played
                color: isPlayed ? VLCStyle.redesign.accent
                                : VLCStyle.redesign.color("#404040", "#9c9c9b")
                opacity: isPlayed ? 0.8 : 1
            }
        }
        // the handle of the seek bar
        Rectangle {
            x: Math.max(0, Math.min(graph.width - width, graph.played * graph.width - width / 2))
            y: VLCStyle.redesign.seekInset
            width: VLCStyle.redesign.seekHandleWidth
            height: graph.height - 2 * VLCStyle.redesign.seekInset
            radius: VLCStyle.redesign.controlRadius
            color: VLCStyle.redesign.accent
        }
    }
}
