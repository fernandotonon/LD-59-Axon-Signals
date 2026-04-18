// Axon Signals — theme "Signal". Single-view puzzle + suggestive biology (no separate 3D scene).
// Clayground / Web Dojo: entry is this file; sibling imports js/signalSim.js and optional Playback helpers.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/signalSim.js" as SignalSim

ApplicationWindow {
    id: win
    visible: true
    width: 960
    height: 640
    title: "Axon Signals — LD Prototype"
    color: "#070910"

    property int segmentCount: 26
    property var myelin: []
    property var lastSim: ({ ok: false, energy: 0, failReason: "", steps: [], nodes: [] })
    property string statusLine: "Click segments to toggle myelin ↔ exposed node stretches."

    // --- Inline signal playback (same view) ---
    property bool playbackActive: false
    property real signalAlong: 0 // 0..1 along axon for pulse + local VFX
    property real ionClock: 0
    property real playbackFailBlend: 0

    function defaultMyelinPattern() {
        var arr = [];
        for (var i = 0; i < segmentCount; i++) {
            if (i === 0 || i === segmentCount - 1)
                arr.push(false);
            else
                arr.push(i % 5 !== 0 && i % 5 !== 1);
        }
        return arr;
    }

    function stopPlayback() {
        playTimer.running = false;
        playbackActive = false;
        signalAlong = 0;
        playbackFailBlend = 0;
    }

    function startSignalPlayback() {
        playTimer.timeline = SignalSim.buildPlaybackTimeline(lastSim.steps, segmentCount);
        playTimer.legIndex = 0;
        playTimer.legU = 0;
        if (playTimer.timeline.length === 0) {
            statusLine = lastSim.ok ? "Signal path ready (no jumps to animate)." : "No propagation legs to play.";
            return;
        }
        playbackActive = true;
        playbackFailBlend = 0;
        playTimer.running = true;
    }

    function resetLevel() {
        stopPlayback();
        myelin = defaultMyelinPattern();
        refreshPreview();
        statusLine = "Foot to brain: toggle myelin — exposed stretches read as nodes of Ranvier.";
    }

    function refreshPreview() {
        lastSim = SignalSim.simulate(myelin, null);
    }

    Component.onCompleted: resetLevel()

    onMyelinChanged: {
        if (!playbackActive)
            refreshPreview();
    }

    function describeFail(code) {
        if (code === "jump_too_far")
            return "saltation gap exceeded the node's reach.";
        if (code === "out_of_energy")
            return "the axon ran out of electrochemical budget.";
        if (code === "no_path")
            return "no valid node layout.";
        return "signal dissipated.";
    }

    function smoothstep(u) {
        return u * u * (3 - 2 * u);
    }

    // Ambient motion for pumps / ions (always on, faster during propagation).
    Timer {
        interval: 48
        repeat: true
        running: true
        onTriggered: win.ionClock += win.playbackActive ? 0.14 : 0.045
    }

    Timer {
        id: playTimer
        interval: 16
        repeat: true
        running: false
        property var timeline: []
        property int legIndex: 0
        property real legU: 0

        onTriggered: {
            if (timeline.length === 0) {
                running = false;
                return;
            }
            var leg = timeline[legIndex];
            var stepScale = (!win.lastSim.ok) ? (1.0 - 0.35 * win.playbackFailBlend) : 1.0;
            legU += (interval / leg.durationMs) * stepScale;
            if (legU >= 1.0) {
                legU = 0;
                legIndex++;
                if (legIndex >= timeline.length) {
                    win.signalAlong = 1.0;
                    win.playbackActive = false;
                    running = false;
                    if (win.lastSim.ok)
                        win.statusLine = "Success — volley reached the soma with energy to spare.";
                    else
                        win.statusLine = "Failed — " + win.describeFail(win.lastSim.failReason);
                    win.refreshPreview();
                    return;
                }
                leg = timeline[legIndex];
            }
            var sm = win.smoothstep(legU);
            win.signalAlong = leg.fromFrac + (leg.toFrac - leg.fromFrac) * sm;
            if (!win.lastSim.ok && legIndex >= timeline.length - 1)
                win.playbackFailBlend = Math.min(1, win.playbackFailBlend + 0.035);
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#05060c" }
            GradientStop { position: 1.0; color: "#0c1220" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Label {
                text: "Axon Signals"
                color: "#e8f6ff"
                font.pixelSize: 26
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "Energy: <b>" + Math.round(lastSim.energy * 10) / 10 + "</b>"
                color: "#7cf5c6"
                textFormat: Text.RichText
                font.pixelSize: 14
            }
            Label {
                text: lastSim.ok ? "<span style='color:#9af'>Ready</span>"
                                 : "<span style='color:#f88'>Risk</span>"
                textFormat: Text.RichText
                font.pixelSize: 14
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: statusLine
            color: "#b8c7dd"
            font.pixelSize: 13
        }

        // --- Membrane strip: one readable row with embedded “biology” cues ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Label {
                text: "Foot"
                color: "#5bd0ff"
                font.bold: true
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 148
                radius: 12
                color: "#0c101c"
                border.color: "#223047"
                border.width: 1

                Flickable {
                    id: axonFlick
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: axonRow.width
                    contentHeight: height
                    clip: true
                    Row {
                        id: axonRow
                        spacing: 5
                        height: 132

                        Repeater {
                            model: win.segmentCount

                            Item {
                                id: cell
                                width: 30
                                height: axonRow.height

                                readonly property bool isEnd: index === 0 || index === win.segmentCount - 1
                                readonly property bool isMyelin: !isEnd && win.myelin[index]
                                readonly property bool isNode: !isEnd && !isMyelin
                                readonly property real sigDist: Math.abs(
                                    index - win.signalAlong * (win.segmentCount - 1))
                                readonly property bool nearPulse: win.playbackActive && sigDist < 1.15
                                readonly property real pulseGlow: {
                                    if (!win.playbackActive)
                                        return 0;
                                    if (sigDist < 0.5)
                                        return 0.65 * (1 - sigDist / 0.5);
                                    return 0;
                                }

                                // Membrane wall (suggestive pseudo-depth)
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: isMyelin ? 26 : 24
                                    height: 102
                                    radius: 10
                                    border.width: isNode ? 2 : 1
                                    border.color: isNode ? "#ff8a3d" : "#1a3044"
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0
                                            color: isEnd ? "#353b4d" : (isMyelin ? "#2a8f52" : "#6d3a22")
                                        }
                                        GradientStop {
                                            position: 0.5
                                            color: isEnd ? "#2a3040" : (isMyelin ? "#1f6b3a" : "#3d2215")
                                        }
                                        GradientStop {
                                            position: 1
                                            color: isEnd ? "#1a1e28" : (isMyelin ? "#14321f" : "#2a150e")
                                        }
                                    }
                                }

                                // Myelin “wrap” lobes (thicker insulation read)
                                Rectangle {
                                    visible: isMyelin
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 92
                                    radius: 4
                                    color: "#1a5c32"
                                    opacity: 0.55
                                    anchors.horizontalCenterOffset: -11
                                }
                                Rectangle {
                                    visible: isMyelin
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 92
                                    radius: 4
                                    color: "#1a5c32"
                                    opacity: 0.55
                                    anchors.horizontalCenterOffset: 11
                                }

                                // Node of Ranvier: exposed channel striations
                                Column {
                                    visible: isNode
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Repeater {
                                        model: 4
                                        Rectangle {
                                            width: 10
                                            height: 2
                                            radius: 1
                                            color: "#ff9a5a"
                                            opacity: 0.35 + index * 0.12
                                        }
                                    }
                                }

                                // Axon lumen (core the pulse rides)
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 6
                                    height: 76
                                    radius: 3
                                    color: "#2ed3ff"
                                    opacity: isEnd ? 0.35 : 0.75
                                }

                                // Na/K pumps (simplified enzyme blobs on membrane)
                                Item {
                                    visible: !isEnd
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 6
                                    width: 26
                                    height: 26
                                    Rectangle {
                                        id: pumpL
                                        x: 2
                                        y: 4
                                        width: 10
                                        height: 16
                                        radius: 3
                                        color: nearPulse ? "#7ea8ff" : "#4d6aa8"
                                        border.color: "#a8c8ff"
                                        border.width: 1
                                        transform: Rotation {
                                            origin.x: 5
                                            origin.y: 8
                                            axis: Qt.vector3d(0, 0, 1)
                                            angle: nearPulse ? 12 * Math.sin(win.ionClock * 2.2)
                                                             : 4 * Math.sin(win.ionClock * 0.9)
                                        }
                                    }
                                    Rectangle {
                                        id: pumpR
                                        x: 14
                                        y: 4
                                        width: 10
                                        height: 16
                                        radius: 3
                                        color: nearPulse ? "#9ab8ff" : "#556db0"
                                        border.color: "#c8d8ff"
                                        border.width: 1
                                        transform: Rotation {
                                            origin.x: 5
                                            origin.y: 8
                                            axis: Qt.vector3d(0, 0, 1)
                                            angle: nearPulse ? -10 * Math.sin(win.ionClock * 2.0 + 0.4)
                                                             : -3 * Math.sin(win.ionClock * 0.85)
                                        }
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: "#ffffaa"
                                        opacity: nearPulse ? 0.55 + 0.35 * Math.sin(win.ionClock * 5) : 0.12
                                    }
                                }

                                // Ion spheres (Na+ gold, K+ violet) — shuffle when pulse is close (suggestive exchange)
                                Item {
                                    visible: !isEnd
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 10
                                    width: 26
                                    height: 22
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: "#ffd54a"
                                        x: 2 + 2 * Math.sin(win.ionClock + index)
                                        y: 4 + (nearPulse ? 5 * Math.sin(win.ionClock * 4) : 2 * Math.sin(win.ionClock))
                                    }
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: "#ffd54a"
                                        x: 12 + 1.5 * Math.sin(win.ionClock * 1.1 + 1)
                                        y: 10 + (nearPulse ? 4 * Math.cos(win.ionClock * 3.5) : 1.5 * Math.cos(win.ionClock))
                                    }
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: "#c77dff"
                                        x: 8 + 2 * Math.cos(win.ionClock * 0.8)
                                        y: 2 + (nearPulse ? 4 * Math.sin(win.ionClock * 3.2 + 0.7) : 1 * Math.sin(win.ionClock))
                                    }
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: "#c77dff"
                                        x: 18 + 1.2 * Math.sin(win.ionClock * 1.3 + 2)
                                        y: 12 + (nearPulse ? 3 * Math.cos(win.ionClock * 4.1) : 1 * Math.cos(win.ionClock))
                                    }
                                }

                                // Traveling pulse read (easy to track)
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 86
                                    radius: 9
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Qt.rgba(0.4, 0.95, 1.0, 0.15 + 0.85 * pulseGlow * (1 - 0.55 * win.playbackFailBlend))
                                    opacity: 0.25 + pulseGlow
                                }

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    text: index === 0 ? "F" : (index === win.segmentCount - 1 ? "B" : "")
                                    color: "#9fe8ff"
                                    font.pixelSize: 9
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !isEnd && !win.playbackActive
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        var copy = win.myelin.slice();
                                        copy[index] = !copy[index];
                                        win.myelin = copy;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Label {
                text: "Brain"
                color: "#d49bff"
                font.bold: true
                font.pixelSize: 12
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            spacing: 10
            Button {
                text: win.playbackActive ? "Running…" : "Send Signal"
                highlighted: true
                enabled: !win.playbackActive
                onClicked: {
                    win.stopPlayback();
                    win.lastSim = SignalSim.simulate(win.myelin, null);
                    win.statusLine = win.lastSim.ok
                            ? "Watch the pulse — pumps and ions flare near the wave (simplified biology)."
                            : "Watch for stalls: spacing and myelin still decide the outcome.";
                    win.startSignalPlayback();
                }
            }
            Button {
                text: "Reset"
                onClicked: win.resetLevel()
            }
            Label {
                text: "Click segments to toggle myelin vs node (Foot/Brain fixed). Scroll if the strip is clipped."
                color: "#7a8699"
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
