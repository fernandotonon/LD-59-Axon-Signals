// Axon Signals — negative Vm puzzle: nodes pull toward 0 mV, myelin re-deepens; collapse if Vm ≥ 0.
// Web Dojo: entry file; sibling js/signalSim.js.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/signalSim.js" as SignalSim
import "js/eduFacts.js" as EduFacts

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
        energy: 100,
        voltage: -70,
        peakVoltage: -70,
        failReason: "",
        steps: [],
        nodes: [],
        config: { startVoltage: -70, brainActivationThreshold: -55, failIfVoltageGte: 0 }
    })
    property string statusLine: "Nodes (gaps + ends) pull Vm toward 0; myelin pushes it negative again. Stay below 0 mV; reach the brain at or below −55 mV."

    property bool playbackActive: false
    property real signalAlong: 0
    property real ionClock: 0
    property real playbackFailBlend: 0
    property real displayVoltage: -55
    property int nodeSpikeSeg: -1
    property real nodeSpikeBoost: 0

    // Optional "Did you know?" markers + one non-modal tip at a time (see js/eduFacts.js).
    property bool learningMode: true
    property string eduTipTopic: ""
    property var eduTipAnchor: null

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
        displayVoltage = (lastSim.config && lastSim.config.startVoltage !== undefined)
                ? lastSim.config.startVoltage : -70;
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
        statusLine = "Foot → Brain: myelin re-strengthens Vm (more negative); each Ranvier node relaxes it toward 0. Never reach 0 mV.";
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
        if (code === "collapsed")
            return "Signal collapsed (voltage reached 0)";
        if (code === "insufficient_activation")
            return "Signal too weak to activate Brain";
        if (code === "no_path")
            return "axon layout invalid.";
        return "propagation failed.";
    }

    function smoothstep(u) {
        return u * u * (3 - 2 * u);
    }

    // More negative Vm → stronger pulse (1). Near 0 mV → weak (approaches 0).
    function signalStrengthFromV(vm) {
        return Math.max(0.12, Math.min(1.0, (-vm) / 80.0));
    }

    // 0 = safe negative Vm; rises toward 1 as Vm approaches 0 from below (collapse risk).
    function collapseRiskFromV(vm) {
        return Math.max(0, Math.min(1, (vm + 16) / 16.0));
    }

    function openLearningTip(topicId, anchorItem) {
        if (!learningMode || topicId.length === 0)
            return;
        eduTipTopic = topicId;
        eduTipAnchor = anchorItem;
        eduPopup.open();
        eduTipRepos.restart();
        eduAutoClose.restart();
    }

    function repositionEduPopup() {
        if (!eduPopup.parent)
            return;
        var over = eduPopup.parent;
        if (!eduTipAnchor) {
            eduPopup.x = (over.width - eduPopup.width) / 2;
            eduPopup.y = 72;
            return;
        }
        var p = eduTipAnchor.mapToItem(over, eduTipAnchor.width / 2, eduTipAnchor.height);
        var w = eduPopup.width;
        var h = eduPopup.implicitHeight > 0 ? eduPopup.implicitHeight : 110;
        var nx = p.x - w / 2;
        nx = Math.max(10, Math.min(over.width - w - 10, nx));
        var ny = p.y + 8;
        ny = Math.max(10, Math.min(over.height - h - 10, ny));
        eduPopup.x = nx;
        eduPopup.y = ny;
    }

    onLearningModeChanged: {
        if (!learningMode) {
            eduAutoClose.stop();
            eduPopup.close();
        }
    }

    onPlaybackActiveChanged: {
        if (playbackActive) {
            eduAutoClose.stop();
            eduPopup.close();
        }
    }

    Timer {
        id: eduTipRepos
        interval: 1
        repeat: false
        onTriggered: win.repositionEduPopup()
    }

    Timer {
        id: eduAutoClose
        interval: 9000
        repeat: false
        onTriggered: eduPopup.close()
    }

    // Inlined for Web Dojo: sibling QML files are not always fetched; avoid Loader + resolvedUrl.
    Component {
        id: learningMarkerComp
        Item {
            id: lmRoot
            property bool learningOn: false
            property string topicId: ""
            property color glowColor: "#3eb8ff"
            property real clock: 0

            readonly property bool lit: learningOn && topicId.length > 0

            implicitWidth: 13
            implicitHeight: 13
            visible: lit

            signal tipOpenRequested(string topicId, Item anchorItem)

            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: lmRoot.glowColor
                opacity: 0.12 + 0.14 * Math.abs(Math.sin(lmRoot.clock * 2.8))
            }

            Rectangle {
                anchors.centerIn: parent
                width: 12
                height: 12
                radius: 6
                color: "#0f1828"
                border.width: 1
                border.color: Qt.lighter(lmRoot.glowColor, 1.25)
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: "i"
                font.pixelSize: 8
                font.bold: true
                color: "#c8e8ff"
            }

            Timer {
                id: lmHoverOpenDelay
                interval: 480
                repeat: false
                onTriggered: {
                    if (lmRoot.lit)
                        lmRoot.tipOpenRequested(lmRoot.topicId, lmRoot);
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: {
                    lmHoverOpenDelay.stop();
                    if (lmRoot.lit)
                        lmRoot.tipOpenRequested(lmRoot.topicId, lmRoot);
                }
                onEntered: {
                    if (lmRoot.lit)
                        lmHoverOpenDelay.restart();
                }
                onExited: lmHoverOpenDelay.stop()
            }
        }
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

            if (leg.kind === "NODE") {
                win.nodeSpikeBoost = Math.max(0, 1 - Math.abs(legU - 0.5) * 2.35);
                win.nodeSpikeSeg = leg.segIndex;
            } else {
                win.nodeSpikeBoost = 0;
                win.nodeSpikeSeg = -1;
            }

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
                    if (win.lastSim.ok) {
                        var thr = (win.lastSim.config && win.lastSim.config.brainActivationThreshold !== undefined)
                                ? win.lastSim.config.brainActivationThreshold : -55;
                        win.statusLine = "Success — Vm reached the brain at or below "
                                + Math.round(thr * 10) / 10 + " mV without collapsing.";
                    }
                    else
                        win.statusLine = "Failed — " + win.describeFail(win.lastSim.failReason);
                    win.refreshPreview();
                    return;
                }
                leg = timeline[legIndex];
                win.displayVoltage = leg.vFrom;
            }
            if (!win.lastSim.ok && leg.kind !== "MYELIN"
                    && win.collapseRiskFromV(win.displayVoltage) > 0.25)
                win.playbackFailBlend = Math.min(1, win.playbackFailBlend + 0.045);
            else if (!win.lastSim.ok && legIndex >= timeline.length - 1)
                win.playbackFailBlend = Math.min(1, win.playbackFailBlend + 0.02);
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
        anchors.margins: 12
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
                text: "Start: <b>" + ((lastSim.config && lastSim.config.startVoltage !== undefined)
                        ? Math.round(lastSim.config.startVoltage * 10) / 10 : -70) + " mV</b>"
                color: "#9fd7ff"
                textFormat: Text.RichText
                font.pixelSize: 12
            }
            Label {
                text: "Brain ≤ <b>" + ((lastSim.config && lastSim.config.brainActivationThreshold !== undefined)
                        ? Math.round(lastSim.config.brainActivationThreshold * 10) / 10 : -55) + " mV</b>"
                color: "#d49bff"
                textFormat: Text.RichText
                font.pixelSize: 12
            }
            Label {
                text: "Vm: <b>" + Math.round((win.playbackActive ? win.displayVoltage : win.lastSim.voltage) * 10) / 10 + " mV</b>"
                color: "#7cf5c6"
                textFormat: Text.RichText
                font.pixelSize: 13
            }
            Label {
                text: "Peak→0: <b>" + Math.round(lastSim.peakVoltage * 10) / 10 + " mV</b>"
                color: "#c8b8ff"
                textFormat: Text.RichText
                font.pixelSize: 11
            }
            Label {
                text: "End Vm: <b>" + Math.round(lastSim.voltage * 10) / 10 + " mV</b>"
                color: "#8ec5ff"
                textFormat: Text.RichText
                font.pixelSize: 11
            }
            Label {
                text: lastSim.ok ? "<span style='color:#9af'>OK</span>" : "<span style='color:#f88'>Risk</span>"
                textFormat: Text.RichText
                font.pixelSize: 13
            }
            Button {
                text: win.learningMode ? "Learning mode: ON" : "Learning mode: OFF"
                flat: true
                font.pixelSize: 11
                onClicked: win.learningMode = !win.learningMode
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
                Layout.preferredWidth: Math.min(axonTrackWidth, Math.max(180, mainCol.width - 96))
                Layout.minimumWidth: 140
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
                                    // True for foot, brain, and every internode Ranvier gap (myelin on both sides).
                                    readonly property bool showEnzymes: SignalSim.isRanvierNode(win.myelin, index, win.segmentCount)
                                    readonly property bool isRanvierGap: !isEnd && !win.myelin[index]
                                            && win.myelin[index - 1] && win.myelin[index + 1]

                                    readonly property real sigDist: Math.abs(
                                        index - win.signalAlong * (win.segmentCount - 1))
                                    readonly property bool nearPulse: win.playbackActive && sigDist < 0.95

                                    readonly property real vmRef: win.playbackActive ? win.displayVoltage : win.lastSim.voltage
                                    readonly property real sigStrength: win.signalStrengthFromV(vmRef)
                                    readonly property real collapseRisk: win.collapseRiskFromV(vmRef)
                                    readonly property real pulseBase: {
                                        if (!win.playbackActive)
                                            return 0;
                                        if (sigDist < 0.48)
                                            return 0.72 * (1 - sigDist / 0.48);
                                        return 0;
                                    }
                                    readonly property real spikeBoost: (win.nodeSpikeSeg === index) ? win.nodeSpikeBoost * 0.95 : 0
                                    readonly property real pulseGlow: {
                                        // No high-frequency flicker on MYELIN — calmer propagation leg.
                                        var flick = (!isMyelin && collapseRisk > 0.2)
                                                ? 0.14 * collapseRisk * Math.abs(Math.sin(win.ionClock * 10.7))
                                                : 0;
                                        return pulseBase * sigStrength * (1 - 0.62 * collapseRisk) * (1 - 0.45 * win.playbackFailBlend) + spikeBoost + flick;
                                    }

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
                                        visible: isRanvierGap
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
                                        z: 8
                                        visible: showEnzymes
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: isEnd ? 4 : 5
                                        width: isEnd ? 26 : 24
                                        height: isEnd ? 26 : 24
                                        Rectangle {
                                            x: isEnd ? 2 : 1
                                            y: isEnd ? 2 : 3
                                            width: isEnd ? 10 : 9
                                            height: isEnd ? 16 : 15
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
                                                        : (isEnd ? 5 : 3) * Math.sin(win.ionClock * 0.85)
                                            }
                                        }
                                        Rectangle {
                                            x: isEnd ? 14 : 13
                                            y: isEnd ? 2 : 3
                                            width: isEnd ? 10 : 9
                                            height: isEnd ? 16 : 15
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
                                                        : (isEnd ? -4 : -2.5) * Math.sin(win.ionClock * 0.8)
                                            }
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: isEnd ? 6 : 5
                                            height: isEnd ? 6 : 5
                                            radius: 2.5
                                            color: "#ffff99"
                                            opacity: spikeBoost > 0.1 ? 0.55 + 0.4 * spikeBoost
                                                                   : (nearPulse ? 0.38 : (isEnd ? 0.22 : 0.12))
                                        }
                                    }

                                    Item {
                                        z: 9
                                        visible: showEnzymes
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: isEnd ? 6 : 8
                                        width: isEnd ? 24 : 22
                                        height: isEnd ? 22 : 20
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
                                        z: 4
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 84
                                        radius: 8
                                        color: "transparent"
                                        border.width: 2
                                        border.color: Qt.rgba(0.35, 0.95, 1.0,
                                            0.1 + 0.82 * pulseGlow + 0.5 * spikeBoost)
                                        opacity: 0.18 + pulseGlow * 0.78 + spikeBoost * 0.48
                                    }

                                    Label {
                                        z: 12
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1
                                        text: index === 0 ? "F" : (index === win.segmentCount - 1 ? "B" : "")
                                        color: "#9fe8ff"
                                        font.pixelSize: 8
                                    }

                                    MouseArea {
                                        z: 15
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

                                    Loader {
                                        z: 22
                                        active: win.learningMode && isMyelin
                                        width: active ? 13 : 0
                                        height: active ? 13 : 0
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 2
                                        anchors.rightMargin: 1
                                        sourceComponent: learningMarkerComp
                                        onLoaded: {
                                            item.topicId = "myelin";
                                            item.glowColor = "#58e8a0";
                                            item.learningOn = Qt.binding(function () {
                                                return win.learningMode;
                                            });
                                            item.clock = Qt.binding(function () {
                                                return win.ionClock;
                                            });
                                            item.tipOpenRequested.connect(function (tid, anch) {
                                                win.openLearningTip(tid, anch);
                                            });
                                        }
                                    }
                                    Loader {
                                        z: 22
                                        active: win.learningMode && isNode
                                        width: active ? 13 : 0
                                        height: active ? 13 : 0
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.topMargin: 2
                                        anchors.leftMargin: 1
                                        sourceComponent: learningMarkerComp
                                        onLoaded: {
                                            item.topicId = "ranvier_node";
                                            item.glowColor = "#ff9a4d";
                                            item.learningOn = Qt.binding(function () {
                                                return win.learningMode;
                                            });
                                            item.clock = Qt.binding(function () {
                                                return win.ionClock;
                                            });
                                            item.tipOpenRequested.connect(function (tid, anch) {
                                                win.openLearningTip(tid, anch);
                                            });
                                        }
                                    }
                                    Loader {
                                        z: 22
                                        active: win.learningMode && showEnzymes
                                        width: active ? 13 : 0
                                        height: active ? 13 : 0
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.rightMargin: 0
                                        sourceComponent: learningMarkerComp
                                        onLoaded: {
                                            item.topicId = "pump";
                                            item.glowColor = "#8eb6ff";
                                            item.learningOn = Qt.binding(function () {
                                                return win.learningMode;
                                            });
                                            item.clock = Qt.binding(function () {
                                                return win.ionClock;
                                            });
                                            item.tipOpenRequested.connect(function (tid, anch) {
                                                win.openLearningTip(tid, anch);
                                            });
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
            Loader {
                id: signalTipLoader
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: win.learningMode ? 16 : 0
                Layout.preferredHeight: win.learningMode ? 16 : 0
                active: win.learningMode
                sourceComponent: learningMarkerComp
                onLoaded: {
                    item.topicId = "signal";
                    item.glowColor = "#7cf5c6";
                    item.learningOn = Qt.binding(function () {
                        return win.learningMode;
                    });
                    item.clock = Qt.binding(function () {
                        return win.ionClock;
                    });
                    item.tipOpenRequested.connect(function (tid, anch) {
                        win.openLearningTip(tid, anch);
                    });
                }
            }
            Button {
                text: win.playbackActive ? "Running…" : "Send Signal"
                highlighted: true
                enabled: !win.playbackActive
                onClicked: {
                    win.stopPlayback();
                    win.lastSim = SignalSim.simulate(win.myelin, null);
                    win.statusLine = win.lastSim.ok
                            ? "Send: keep Vm below 0 mV and finish the brain at or below −55 mV."
                            : "Risk: too many nodes drag Vm toward 0; myelin must pull it negative again before collapse.";
                    win.startSignalPlayback();
                }
            }
            Button {
                text: "Reset"
                onClicked: win.resetLevel()
            }
            Label {
                text: "Click interior cells to toggle myelin. Pumps + ions on every Ranvier site (gaps between sheaths, foot, brain). Track width scales with segment count."
                color: "#7a8699"
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }

    Popup {
        id: eduPopup
        // Web Dojo / WASM: win.overlay is often missing; contentItem always exists.
        parent: win.contentItem
        z: 100000
        modal: false
        focus: false
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(340, Math.max(200, win.contentItem.width - 24))

        onClosed: {
            eduAutoClose.stop();
            win.eduTipTopic = "";
            win.eduTipAnchor = null;
        }

        onWidthChanged: if (visible)
            win.repositionEduPopup()

        background: Rectangle {
            color: "#0a101c"
            border.color: "#3d6a9e"
            border.width: 1
            radius: 10

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 1
                width: 4
                height: parent.height - 2
                radius: 2
                color: "#2ed3ff"
                opacity: 0.35
            }
        }

        contentItem: ColumnLayout {
            spacing: 8
            width: eduPopup.availableWidth

            Label {
                text: EduFacts.titleFor(win.eduTipTopic)
                color: "#9fd7ff"
                font.pixelSize: 11
                font.bold: true
                font.capitalization: Font.AllUppercase
                letterSpacing: 0.6
                Layout.fillWidth: true
            }
            Label {
                text: EduFacts.textFor(win.eduTipTopic)
                color: "#d4e4f5"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    text: "Got it"
                    flat: true
                    font.pixelSize: 11
                    onClicked: eduPopup.close()
                }
            }
        }
    }
}
