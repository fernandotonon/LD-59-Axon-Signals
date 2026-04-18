// Axon Signals — simplified Vm + ATP model; Ranvier pumps only; single view.
// Web Dojo: entry file; sibling js/signalSim.js.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/signalSim.js" as SignalSim

ApplicationWindow {
    id: win
    visible: true
    width: 960
    height: 680
    title: "Axon Signals — LD Prototype"
    color: "#070910"

    property int segmentCount: 26
    property int cellOuterWidth: 28
    property int axonSpacing: 4
    readonly property int axonTrackWidth: segmentCount * cellOuterWidth + (segmentCount - 1) * axonSpacing + 24

    property var myelin: []
    property var lastSim: ({
        ok: false,
        energy: 0,
        voltage: -55,
        minVoltage: -55,
        failReason: "",
        steps: [],
        nodes: []
    })
    property string statusLine: "Toggle myelin so Ranvier gaps sit between sheaths — pumps only appear there."

    property bool playbackActive: false
    property real signalAlong: 0
    property real ionClock: 0
    property real playbackFailBlend: 0
    property real displayVoltage: -55
    property int nodeSpikeSeg: -1
    property real nodeSpikeBoost: 0

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
        nodeSpikeSeg = -1;
        nodeSpikeBoost = 0;
        displayVoltage = -55;
    }

    function startSignalPlayback() {
        playTimer.timeline = SignalSim.buildPlaybackTimeline(lastSim.steps, segmentCount);
        playTimer.legIndex = 0;
        playTimer.legU = 0;
        if (playTimer.timeline.length === 0) {
            statusLine = "Nothing to animate.";
            return;
        }
        playbackActive = true;
        playbackFailBlend = 0;
        displayVoltage = playTimer.timeline[0].vFrom;
        playTimer.running = true;
    }

    function resetLevel() {
        stopPlayback();
        myelin = defaultMyelinPattern();
        refreshPreview();
        statusLine = "Foot → Brain: myelin decays Vm slowly; Ranvier nodes spend ATP and reset Vm to −55 mV.";
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
        if (code === "under_voltage")
            return "membrane potential fell past −70 mV.";
        if (code === "out_of_energy")
            return "ATP ran out before the signal finished.";
        if (code === "no_path")
            return "axon layout invalid.";
        return "propagation failed.";
    }

    function smoothstep(u) {
        return u * u * (3 - 2 * u);
    }

    // Voltage → 0..1 glow headroom above failure threshold (−70 mV), capped toward −50 mV.
    function voltageGlowNorm(vm) {
        return Math.max(0, Math.min(1, (vm - (-70)) / ((-50) - (-70))));
    }

    Timer {
        interval: 48
        repeat: true
        running: true
        onTriggered: win.ionClock += win.playbackActive ? 0.14 : 0.04
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
            var sm = win.smoothstep(Math.min(1, legU));
            win.signalAlong = leg.fromFrac + (leg.toFrac - leg.fromFrac) * sm;
            win.displayVoltage = leg.vFrom + (leg.vTo - leg.vFrom) * sm;

            if (leg.nodeFlash)
                win.nodeSpikeBoost = Math.max(0, 1 - Math.abs(legU - 0.5) * 2.35);
            else
                win.nodeSpikeBoost = 0;
            win.nodeSpikeSeg = leg.nodeFlash ? leg.segIndex : -1;

            if (legU >= 1.0) {
                legU = 0;
                legIndex++;
                win.nodeSpikeBoost = 0;
                win.nodeSpikeSeg = -1;
                if (legIndex >= timeline.length) {
                    win.signalAlong = 1.0;
                    win.displayVoltage = win.lastSim.voltage;
                    win.playbackActive = false;
                    running = false;
                    if (win.lastSim.ok)
                        win.statusLine = "Success — Vm and ATP both healthy at the soma.";
                    else
                        win.statusLine = "Failed — " + win.describeFail(win.lastSim.failReason);
                    win.refreshPreview();
                    return;
                }
                leg = timeline[legIndex];
                win.displayVoltage = leg.vFrom;
            }
            if (!win.lastSim.ok && legIndex >= timeline.length - 1)
                win.playbackFailBlend = Math.min(1, win.playbackFailBlend + 0.03);
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
        id: mainCol
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Label {
                text: "Axon Signals"
                color: "#e8f6ff"
                font.pixelSize: 24
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "ATP: <b>" + Math.round(lastSim.energy * 10) / 10 + "</b>"
                color: "#7cf5c6"
                textFormat: Text.RichText
                font.pixelSize: 13
            }
            Label {
                text: "Vm (end): <b>" + Math.round(lastSim.voltage * 10) / 10 + " mV</b>"
                color: "#9fd7ff"
                textFormat: Text.RichText
                font.pixelSize: 13
            }
            Label {
                text: "Vm min: <b>" + Math.round(lastSim.minVoltage * 10) / 10 + " mV</b>"
                color: "#c8b8ff"
                textFormat: Text.RichText
                font.pixelSize: 12
            }
            Label {
                text: lastSim.ok ? "<span style='color:#9af'>OK</span>" : "<span style='color:#f88'>Risk</span>"
                textFormat: Text.RichText
                font.pixelSize: 13
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: statusLine
            color: "#b8c7dd"
            font.pixelSize: 12
        }

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

            Item {
                id: axonBand
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(axonTrackWidth, Math.max(200, mainCol.width - 120))
                Layout.minimumWidth: 160
                height: 156
                clip: false

                Rectangle {
                    anchors.fill: parent
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
                            spacing: axonSpacing
                            height: 132
                            x: Math.max(0, (axonFlick.width - width) / 2)

                            Repeater {
                                model: win.segmentCount

                                Item {
                                    id: cell
                                    width: win.cellOuterWidth
                                    height: axonRow.height

                                    readonly property bool isEnd: index === 0 || index === win.segmentCount - 1
                                    readonly property string segKind: SignalSim.segmentKind(win.myelin, index, win.segmentCount)
                                    readonly property bool isMyelin: segKind === "MYELIN"
                                    readonly property bool isNode: segKind === "NODE"
                                    readonly property bool isLeak: segKind === "LEAKY"

                                    readonly property real sigDist: Math.abs(
                                        index - win.signalAlong * (win.segmentCount - 1))
                                    readonly property bool nearPulse: win.playbackActive && sigDist < 0.95

                                    readonly property real vNorm: win.playbackActive
                                            ? win.voltageGlowNorm(win.displayVoltage)
                                            : win.voltageGlowNorm(win.lastSim.voltage)
                                    readonly property real pulseBase: {
                                        if (!win.playbackActive)
                                            return 0;
                                        if (sigDist < 0.48)
                                            return 0.72 * (1 - sigDist / 0.48);
                                        return 0;
                                    }
                                    readonly property real pulseGlow: pulseBase * (0.35 + 0.65 * vNorm) * (1 - 0.55 * win.playbackFailBlend)
                                    readonly property real spikeBoost: (win.nodeSpikeSeg === index) ? win.nodeSpikeBoost * 0.95 : 0

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: isMyelin ? 24 : 22
                                        height: 100
                                        radius: 9
                                        border.width: isNode ? 2 : (isLeak ? 1 : 1)
                                        border.color: isNode ? "#ff9a4d" : (isLeak ? "#7a4a2a" : "#1e3a28")
                                        gradient: Gradient {
                                            GradientStop {
                                                position: 0
                                                color: isMyelin ? "#2d9a58" : (isNode ? "#7a4528" : "#5a3020")
                                            }
                                            GradientStop {
                                                position: 0.5
                                                color: isMyelin ? "#1f6b3a" : (isNode ? "#4a2818" : "#3d2215")
                                            }
                                            GradientStop {
                                                position: 1
                                                color: isMyelin ? "#14321f" : (isNode ? "#2a150e" : "#241208")
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: isMyelin
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7
                                        height: 90
                                        radius: 3
                                        color: "#1a5c32"
                                        opacity: 0.5
                                        anchors.horizontalCenterOffset: -10
                                    }
                                    Rectangle {
                                        visible: isMyelin
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 7
                                        height: 90
                                        radius: 3
                                        color: "#1a5c32"
                                        opacity: 0.5
                                        anchors.horizontalCenterOffset: 10
                                    }

                                    Column {
                                        visible: isNode
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                width: 9
                                                height: 2
                                                radius: 1
                                                color: "#ffb070"
                                                opacity: 0.4 + index * 0.14
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 5
                                        height: 74
                                        radius: 2
                                        color: "#2ed3ff"
                                        opacity: isMyelin ? 0.25 : 0.72
                                    }

                                    Item {
                                        visible: isNode
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 5
                                        width: 24
                                        height: 24
                                        Rectangle {
                                            x: 1
                                            y: 3
                                            width: 9
                                            height: 15
                                            radius: 3
                                            color: (nearPulse || spikeBoost > 0.2) ? "#8eb6ff" : "#4d6aa8"
                                            border.color: "#bcd6ff"
                                            border.width: 1
                                            transform: Rotation {
                                                origin.x: 4.5
                                                origin.y: 7.5
                                                axis: Qt.vector3d(0, 0, 1)
                                                angle: (nearPulse || spikeBoost > 0.15)
                                                        ? 14 * Math.sin(win.ionClock * 2.4)
                                                        : 3 * Math.sin(win.ionClock * 0.85)
                                            }
                                        }
                                        Rectangle {
                                            x: 13
                                            y: 3
                                            width: 9
                                            height: 15
                                            radius: 3
                                            color: (nearPulse || spikeBoost > 0.2) ? "#a8c4ff" : "#556db0"
                                            border.color: "#dce8ff"
                                            border.width: 1
                                            transform: Rotation {
                                                origin.x: 4.5
                                                origin.y: 7.5
                                                axis: Qt.vector3d(0, 0, 1)
                                                angle: (nearPulse || spikeBoost > 0.15)
                                                        ? -12 * Math.sin(win.ionClock * 2.1 + 0.3)
                                                        : -2.5 * Math.sin(win.ionClock * 0.8)
                                            }
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: "#ffff99"
                                            opacity: spikeBoost > 0.1 ? 0.5 + 0.45 * spikeBoost : (nearPulse ? 0.35 : 0.1)
                                        }
                                    }

                                    Item {
                                        visible: isNode
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        width: 22
                                        height: 20
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: "#ffd54a"
                                            x: 2 + 2 * Math.sin(win.ionClock + index)
                                            y: 4 + (nearPulse ? 5 * Math.sin(win.ionClock * 4) : 2 * Math.sin(win.ionClock))
                                        }
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: "#ffd54a"
                                            x: 11
                                            y: 10 + (nearPulse ? 4 * Math.cos(win.ionClock * 3.5) : 1.5 * Math.cos(win.ionClock))
                                        }
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: "#c77dff"
                                            x: 7 + 2 * Math.cos(win.ionClock * 0.9)
                                            y: 2 + (nearPulse ? 4 * Math.sin(win.ionClock * 3.2) : 1 * Math.sin(win.ionClock))
                                        }
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: "#c77dff"
                                            x: 16
                                            y: 12 + (nearPulse ? 3 * Math.cos(win.ionClock * 4) : 1 * Math.cos(win.ionClock))
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 84
                                        radius: 8
                                        color: "transparent"
                                        border.width: 2
                                        border.color: Qt.rgba(0.35, 0.95, 1.0,
                                            0.12 + 0.78 * pulseGlow + 0.55 * spikeBoost)
                                        opacity: 0.2 + pulseGlow * 0.75 + spikeBoost * 0.5
                                    }

                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1
                                        text: index === 0 ? "F" : (index === win.segmentCount - 1 ? "B" : "")
                                        color: "#9fe8ff"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !isEnd && !win.playbackActive
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                            ? "Send: Vm holds above −70 mV and ATP > 0 at the brain — watch the pulse."
                            : "Risk: long myelin runs leak Vm; every real node spends ATP to reset Vm to −55 mV.";
                    win.startSignalPlayback();
                }
            }
            Button {
                text: "Reset"
                onClicked: win.resetLevel()
            }
            Label {
                text: "Click interior cells to toggle myelin. Pumps / ions only at Ranvier gaps (between sheaths) and ends. Track width scales with segment count."
                color: "#7a8699"
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
