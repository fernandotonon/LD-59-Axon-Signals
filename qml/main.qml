// Axon Signals - saltatory conduction puzzle (signal strength + ATP). Web Dojo: sibling js/signalSim.js.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/signalSim.js" as SignalSim
import "js/levels.js" as Levels

ApplicationWindow {
    id: win
    visible: true
    width: 1000
    height: 820
    title: "Axon Signals"
    color: "#060814"

    property int segmentCount: 26
    property int cellOuterWidth: 44
    property int axonSpacing: 8
    readonly property int axonRowHeight: 186
    readonly property int axonTrackWidth: segmentCount * cellOuterWidth + (segmentCount - 1) * axonSpacing + 24
    // Dense [0..n-1] for Repeater; assigned in syncAxonIndices (not a readonly recompute) so Web/Qt builds
    // do not collapse delegates or mis-bind modelData.
    property var axonIndices: []

    property var myelin: []
    property var lastSim: ({
        ok: true,
        signalStrength: 100,
        atp: 8,
        voltage: -70,
        peakVoltage: -70,
        lowestSignalStrength: 100,
        failReason: "",
        steps: [],
        nodes: [],
        config: {
            restingPotential: -70,
            thresholdPotential: -55,
            initialSignalStrength: 100,
            brainActivationThreshold: 40,
            signalThresholdToFireNode: 35
        }
    })
    property string statusLine: ""

    property int currentLevelIndex: 0
    property int selectedPathIndex: 0
    property var activePaths: []
    property var pathMyelinCache: ({})
    property bool pendingNextLevel: false
    property string timePressureText: ""

    property bool playbackActive: false
    property real signalAlong: 0
    property real ionClock: 0
    property real playbackFailBlend: 0
    property real displayVoltage: -70
    property real displaySignalStrength: 100
    property int displayAtp: 8
    property int nodeSpikeSeg: -1
    property real nodeSpikeBoost: 0

    property bool learningMode: false
    property string dykPanelText: ""
    readonly property var didYouKnowFacts: ({
        "myelin": "Did you know? Myelin acts as insulation, allowing signals to travel faster along neurons.",
        "ranvier": "Did you know? Nodes of Ranvier are gaps where the signal is actively regenerated.",
        "pump": "Did you know? Sodium-potassium pumps help restore the balance of ions after a signal passes.",
        "signal": "Did you know? A neural signal is actually an electrical change in voltage across the membrane."
    })

    property string dykHoverArmed: ""

    function showDidYouKnow(key) {
        if (!learningMode)
            return;
        var t = didYouKnowFacts[key];
        if (!t)
            return;
        dykHoverArmed = "";
        dykHoverTimer.stop();
        dykPanelText = t;
        dykAutoClose.restart();
    }

    function dismissDidYouKnow() {
        dykPanelText = "";
        dykAutoClose.stop();
    }

    function armDykHover(key) {
        if (!learningMode)
            return;
        dykHoverArmed = key;
        dykHoverTimer.restart();
    }

    function disarmDykHover(key) {
        if (dykHoverArmed === key) {
            dykHoverArmed = "";
            dykHoverTimer.stop();
        }
    }

    Timer {
        id: dykHoverTimer
        interval: 420
        repeat: false
        onTriggered: {
            if (win.learningMode && win.dykHoverArmed !== "")
                win.showDidYouKnow(win.dykHoverArmed);
        }
    }

    Timer {
        id: dykAutoClose
        interval: 5500
        repeat: false
        onTriggered: win.dismissDidYouKnow()
    }

    function syncAxonIndices() {
        var a = [];
        for (var k = 0; k < segmentCount; k++)
            a.push(k);
        axonIndices = a;
    }

    function cacheKey() {
        return currentLevelIndex + "_" + selectedPathIndex;
    }

    function mergedSim() {
        if (!activePaths.length)
            return Levels.mergeSim(Levels.getLevel(0), { initialATP: 10 });
        return Levels.mergeSim(Levels.getLevel(currentLevelIndex), activePaths[selectedPathIndex]);
    }

    function saveMyelinToCache() {
        var k = cacheKey();
        var o = {};
        for (var p in pathMyelinCache)
            o[p] = pathMyelinCache[p];
        o[k] = myelin.slice();
        pathMyelinCache = o;
    }

    function selectPath(idx) {
        if (idx === selectedPathIndex || idx < 0 || idx >= activePaths.length)
            return;
        saveMyelinToCache();
        selectedPathIndex = idx;
        var path = activePaths[idx];
        segmentCount = path.segmentCount;
        syncAxonIndices();
        var k = cacheKey();
        var snap = pathMyelinCache[k];
        myelin = snap ? snap.slice() : path.defaultMyelin.slice();
        stopPlayback();
        refreshPreview();
        pendingNextLevel = false;
        statusLine = Levels.getLevel(currentLevelIndex).scenarioText + " (" + path.label + ")";
    }

    function applyLevel(idx) {
        stopPlayback();
        currentLevelIndex = idx;
        selectedPathIndex = 0;
        pathMyelinCache = {};
        var L = Levels.getLevel(idx);
        activePaths = L.paths;
        title = "Axon Signals — " + L.title;
        timePressureText = L.timePressureLabel;
        var path0 = activePaths[0];
        segmentCount = path0.segmentCount;
        syncAxonIndices();
        myelin = path0.defaultMyelin.slice();
        pendingNextLevel = false;
        refreshPreview();
        statusLine = L.scenarioText + " Choose a path, adjust myelin, then Send Signal.";
    }

    function restartCurrentLevel() {
        stopPlayback();
        if (!activePaths.length)
            return;
        var path = activePaths[selectedPathIndex];
        myelin = path.defaultMyelin.slice();
        saveMyelinToCache();
        refreshPreview();
        var L = Levels.getLevel(currentLevelIndex);
        statusLine = L.scenarioText + " Layout reset — try again.";
        pendingNextLevel = false;
    }

    function goNextLevel() {
        if (currentLevelIndex + 1 >= Levels.levelCount())
            return;
        applyLevel(currentLevelIndex + 1);
    }

    function pathMyelinByte(pathIdx, segIdx) {
        if (pathIdx === selectedPathIndex) {
            if (myelin && segIdx < myelin.length)
                return !!myelin[segIdx];
        }
        var k2 = currentLevelIndex + "_" + pathIdx;
        var arr = pathMyelinCache[k2];
        if (!arr && activePaths[pathIdx])
            arr = activePaths[pathIdx].defaultMyelin;
        if (!arr || segIdx >= arr.length)
            return false;
        return !!arr[segIdx];
    }

    function stopPlayback() {
        playTimer.running = false;
        playbackActive = false;
        signalAlong = 0;
        playbackFailBlend = 0;
        nodeSpikeSeg = -1;
        nodeSpikeBoost = 0;
        displaySignalStrength = lastSim.signalStrength !== undefined ? lastSim.signalStrength : 100;
        displayAtp = lastSim.atp !== undefined ? lastSim.atp : 8;
        displayVoltage = lastSim.voltage !== undefined ? lastSim.voltage : -70;
    }

    function startSignalPlayback() {
        playTimer.timeline = SignalSim.buildPlaybackTimeline(lastSim.steps, segmentCount, lastSim.config);
        playTimer.legIndex = 0;
        playTimer.legU = 0;
        if (playTimer.timeline.length === 0) {
            statusLine = "Nothing to animate.";
            return;
        }
        playbackActive = true;
        playbackFailBlend = 0;
        var leg0 = playTimer.timeline[0];
        displaySignalStrength = leg0.strengthFrom;
        displayAtp = leg0.atpFrom;
        displayVoltage = SignalSim.strengthToDisplayVm(displaySignalStrength, lastSim.config);
        playTimer.running = true;
    }

    function refreshPreview() {
        lastSim = SignalSim.simulate(myelin, mergedSim());
    }

    Component.onCompleted: {
        applyLevel(0);
    }

    onSegmentCountChanged: syncAxonIndices()

    onMyelinChanged: {
        if (!playbackActive) {
            saveMyelinToCache();
            refreshPreview();
        }
    }

    function describeFail(code) {
        if (code === "faded_before_node")
            return "Signal faded before the next node";
        if (code === "atp_exhausted")
            return "Not enough ATP to regenerate signal";
        if (code === "brain_weak")
            return "Signal too weak to activate Brain";
        if (code === "no_path")
            return "Axon layout invalid.";
        return "Propagation failed.";
    }

    function smoothstep(u) {
        return u * u * (3 - 2 * u);
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
            win.displaySignalStrength = leg.strengthFrom + (leg.strengthTo - leg.strengthFrom) * sm;
            win.displayAtp = Math.round(leg.atpFrom + (leg.atpTo - leg.atpFrom) * sm);
            win.displayVoltage = SignalSim.strengthToDisplayVm(win.displaySignalStrength, win.lastSim.config);

            if (leg.nodeFlash) {
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
                    win.displaySignalStrength = win.lastSim.signalStrength;
                    win.displayAtp = win.lastSim.atp;
                    win.displayVoltage = win.lastSim.voltage;
                    win.playbackActive = false;
                    running = false;
                    if (win.lastSim.ok) {
                        var thr = (win.lastSim.config && win.lastSim.config.brainActivationThreshold !== undefined)
                                ? win.lastSim.config.brainActivationThreshold : 40;
                        var L = Levels.getLevel(win.currentLevelIndex);
                        win.statusLine = L.successFeedback + " Strength "
                                + Math.round(win.lastSim.signalStrength) + " (needed >= " + Math.round(thr) + ").";
                        if (win.currentLevelIndex + 1 >= Levels.levelCount()) {
                            win.statusLine += " All scenarios cleared!";
                            win.pendingNextLevel = false;
                        } else {
                            win.pendingNextLevel = true;
                        }
                    } else {
                        var Lf = Levels.getLevel(win.currentLevelIndex);
                        win.statusLine = Lf.failFeedback + " (" + win.describeFail(win.lastSim.failReason) + ")";
                        win.pendingNextLevel = false;
                    }
                    win.refreshPreview();
                    return;
                }
                leg = timeline[legIndex];
                win.displaySignalStrength = leg.strengthFrom;
                win.displayAtp = leg.atpFrom;
                win.displayVoltage = SignalSim.strengthToDisplayVm(leg.strengthFrom, win.lastSim.config);
            }
            var cap = (win.lastSim.config && win.lastSim.config.initialSignalStrength)
                    ? win.lastSim.config.initialSignalStrength : 100;
            var risk = 1.0 - Math.max(0, Math.min(1, win.displaySignalStrength / cap));
            if (!win.lastSim.ok && leg.phase !== "decay" && risk > 0.28)
                win.playbackFailBlend = Math.min(1, win.playbackFailBlend + 0.045);
            else if (!win.lastSim.ok && legIndex >= timeline.length - 1)
                win.playbackFailBlend = Math.min(1, win.playbackFailBlend + 0.02);
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#070a18" }
            GradientStop { position: 0.55; color: "#0a0d22" }
            GradientStop { position: 1.0; color: "#120a1e" }
        }
    }

    MouseArea {
        z: 9998
        anchors.fill: parent
        visible: win.dykPanelText.length > 0
        acceptedButtons: Qt.AllButtons
        hoverEnabled: false
        onClicked: win.dismissDidYouKnow()
    }

    Rectangle {
        id: dykPanel
        z: 10000
        visible: win.dykPanelText.length > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 52
        width: Math.min(440, parent.width - 36)
        height: Math.min(132, Math.max(50, dykBody.implicitHeight + 26))
        radius: 10
        color: "#0c1424"
        border.width: 1
        border.color: Qt.rgba(0.35, 0.85, 1.0, 0.55)
        opacity: 0.97

        Rectangle {
            z: 0
            anchors.fill: parent
            anchors.margins: 1
            radius: 9
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0.5, 0.95, 1.0, 0.12)
        }

        Label {
            id: dykBody
            z: 1
            anchors.left: parent.left
            anchors.right: closeHit.left
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 6
            anchors.topMargin: 12
            text: win.dykPanelText
            wrapMode: Text.WordWrap
            color: "#c8dff0"
            font.pixelSize: 12
        }

        Item {
            id: closeHit
            z: 2
            width: 28
            height: 28
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            MouseArea {
                anchors.fill: parent
                onClicked: win.dismissDidYouKnow()
                cursorShape: Qt.PointingHandCursor
            }
            Label {
                anchors.centerIn: parent
                text: "x"
                color: "#7ad8ff"
                font.pixelSize: 14
            }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            RowLayout {
                spacing: 10
                Label {
                    text: "Axon Signals"
                    color: "#eef3f8"
                    font.pixelSize: 20
                    font.bold: true
                }
                Button {
                    text: "Neuron rules"
                    font.pixelSize: 11
                    flat: true
                    onClicked: howDrawer.open()
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                spacing: 4
                Label {
                    Layout.alignment: Qt.AlignRight
                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.RichText
                    font.pixelSize: 11
                    color: "#aeb8c9"
                    text: "<span style='color:#c5ccd6'>Signal</span> <b style='color:#f2fdff'>"
                            + Math.round(win.playbackActive ? win.displaySignalStrength : win.lastSim.signalStrength)
                            + "</b> &nbsp;<span style='color:#6d7688'>|</span>&nbsp; "
                            + "<span style='color:#c5ccd6'>ATP</span> <b style='color:#cdeee0'>"
                            + (win.playbackActive ? win.displayAtp : win.lastSim.atp) + "</b>"
                }
                Label {
                    Layout.alignment: Qt.AlignRight
                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.RichText
                    font.pixelSize: 10
                    color: "#949eac"
                    text: "Goal: Reach <b>Brain</b> · strength ≥ <b>"
                            + ((lastSim.config && lastSim.config.brainActivationThreshold !== undefined)
                               ? Math.round(lastSim.config.brainActivationThreshold) : 40) + "</b>"
                }
                Label {
                    Layout.alignment: Qt.AlignRight
                    horizontalAlignment: Text.AlignRight
                    textFormat: Text.RichText
                    font.pixelSize: 9
                    color: "#7a8494"
                    text: "Weakest <b>" + Math.round(lastSim.lowestSignalStrength !== undefined
                            ? lastSim.lowestSignalStrength : lastSim.signalStrength) + "</b> · "
                            + (lastSim.ok ? "<span style='color:#9dd8b8'>stable</span>"
                                          : "<span style='color:#f0a8a8'>risk</span>")
                }
            }
            Item {
                id: signalDykMarker
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                Layout.alignment: Qt.AlignVCenter
                visible: win.learningMode
                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: Qt.rgba(0.12, 0.35, 0.45, 0.85)
                    border.width: 1
                    border.color: Qt.rgba(0.45, 0.85, 1.0, 0.45 + 0.35 * Math.sin(win.ionClock * 2.8))
                }
                Label {
                    anchors.centerIn: parent
                    text: "i"
                    color: "#9fd7ff"
                    font.pixelSize: 8
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.showDidYouKnow("signal")
                    onEntered: win.armDykHover("signal")
                    onExited: win.disarmDykHover("signal")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: win.axonRowHeight + 48
            spacing: 10
            Label {
                text: Levels.getLevel(currentLevelIndex).startOrgan
                color: "#aeb9ca"
                font.bold: true
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 58
                wrapMode: Text.WordWrap
            }

            Item {
                id: axonBand
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: win.axonRowHeight + 32

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: Qt.rgba(0.04, 0.06, 0.11, 0.45)
                    border.width: 1
                    border.color: Qt.rgba(0.55, 0.58, 0.78, 0.12)
                }

                Flickable {
                    id: axonFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: axonRow.width
                    contentHeight: height
                    clip: true
                    Row {
                        id: axonRow
                        spacing: win.axonSpacing
                        height: win.axonRowHeight
                        x: Math.max(0, (axonFlick.width - width) / 2)

                        Repeater {
                            model: win.axonIndices

                                Item {
                                    width: win.cellOuterWidth
                                    height: axonRow.height

                                    readonly property int axonIndex: ((typeof modelData !== "undefined") && (modelData !== null)) ? modelData : index
                                    readonly property bool isEnd: axonIndex === 0 || axonIndex === win.segmentCount - 1
                                    readonly property bool isMyelin: {
                                        var m = win.myelin;
                                        var i = axonIndex;
                                        if (!m || i < 0 || i >= m.length)
                                            return false;
                                        return !!m[i];
                                    }
                                    readonly property bool isRanvier: !isMyelin

                                    readonly property real sigDist: Math.abs(
                                            axonIndex - win.signalAlong * (win.segmentCount - 1))
                                    readonly property bool nearPulse: win.playbackActive && sigDist < 0.68

                                    readonly property real liveStrength: win.playbackActive ? win.displaySignalStrength : win.lastSim.signalStrength
                                    readonly property real strCap: (win.lastSim.config && win.lastSim.config.initialSignalStrength)
                                            ? win.lastSim.config.initialSignalStrength : 100
                                    readonly property real normStrength: Math.max(0, Math.min(1, liveStrength / strCap))
                                    readonly property real collapseRisk: 1.0 - normStrength
                                    readonly property real pulseFlicker: collapseRisk > 0.36
                                            ? (0.48 + 0.52 * Math.abs(Math.sin(win.ionClock * (10.0 + 24.0 * collapseRisk))))
                                            : (0.9 + 0.1 * Math.sin(win.ionClock * 2.6))
                                    readonly property real spikeBoost: (win.nodeSpikeSeg === axonIndex) ? win.nodeSpikeBoost : 0

                                    Item {
                                        z: 25
                                        anchors.centerIn: parent
                                        width: parent.width * 2.55
                                        height: parent.height * 0.92
                                        visible: nearPulse
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.92
                                            height: parent.height * 0.86
                                            radius: width * 0.5
                                            color: Qt.rgba(0.32, 0.74, 1.0, (0.08 + 0.44 * parent.parent.normStrength) * parent.parent.pulseFlicker)
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.54
                                            height: parent.height * 0.58
                                            radius: width * 0.5
                                            color: Qt.rgba(0.88, 0.96, 1.0, (0.22 + 0.68 * parent.parent.normStrength) * parent.parent.pulseFlicker)
                                            border.width: 2
                                            border.color: Qt.rgba(0.45, 0.88, 1.0, 0.95)
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width * 0.24
                                            height: parent.height * 0.26
                                            radius: width * 0.5
                                            color: Qt.rgba(1, 1, 1, 0.42 + 0.55 * parent.parent.normStrength)
                                        }
                                    }

                                    Rectangle {
                                        z: 0
                                        visible: isMyelin
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 30
                                        height: 124
                                        radius: 15
                                        color: "#2a4540"
                                        border.width: 1
                                        border.color: "#1e3430"
                                    }

                                    Rectangle {
                                        z: 0
                                        visible: isRanvier
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 34
                                        height: 130
                                        radius: 17
                                        color: "#231a16"
                                        border.width: 2
                                        border.color: Qt.rgba(1, 0.48, 0.18, 0.42 + 0.4 * spikeBoost + (nearPulse ? 0.22 : 0))
                                    }
                                    Rectangle {
                                        z: 1
                                        visible: isRanvier
                                        anchors.centerIn: parent
                                        width: 46
                                        height: 142
                                        radius: 23
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 0.42, 0.15, 0.14 + 0.3 * spikeBoost + 0.22 * nearPulse)
                                    }
                                    Rectangle {
                                        z: 2
                                        visible: isRanvier
                                        anchors.centerIn: parent
                                        width: 26
                                        height: 112
                                        radius: 13
                                        color: "transparent"
                                        border.width: 3
                                        border.color: Qt.rgba(1, 0.52, 0.22, 0.52 + 0.38 * spikeBoost + (nearPulse ? 0.2 : 0))
                                    }

                                    Rectangle {
                                        z: 3
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 4
                                        height: isMyelin ? 70 : 88
                                        radius: 2
                                        color: isMyelin ? Qt.rgba(0.42, 0.68, 0.6, 0.2) : Qt.rgba(1, 0.5, 0.22, 0.16)
                                        visible: isMyelin || isRanvier
                                    }

                                    Item {
                                        z: 8
                                        visible: isRanvier
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 10
                                        width: 26
                                        height: 26
                                        Rectangle {
                                            x: 1
                                            y: 4
                                            width: 9
                                            height: 16
                                            radius: 3
                                            color: (nearPulse || spikeBoost > 0.2) ? "#9eb8e8" : "#556892"
                                            border.color: "#c8daf8"
                                            border.width: 1
                                            transform: Rotation {
                                                origin.x: 4.5
                                                origin.y: 8
                                                axis: Qt.vector3d(0, 0, 1)
                                                angle: (nearPulse || spikeBoost > 0.15)
                                                        ? 16 * Math.sin(win.ionClock * 2.4)
                                                        : 3 * Math.sin(win.ionClock * 0.85)
                                            }
                                        }
                                        Rectangle {
                                            x: 14
                                            y: 4
                                            width: 9
                                            height: 16
                                            radius: 3
                                            color: (nearPulse || spikeBoost > 0.2) ? "#b4c8f5" : "#5c6fa0"
                                            border.color: "#e2ebff"
                                            border.width: 1
                                            transform: Rotation {
                                                origin.x: 4.5
                                                origin.y: 8
                                                axis: Qt.vector3d(0, 0, 1)
                                                angle: (nearPulse || spikeBoost > 0.15)
                                                        ? -14 * Math.sin(win.ionClock * 2.1 + 0.3)
                                                        : -2.5 * Math.sin(win.ionClock * 0.8)
                                            }
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 5
                                            height: 5
                                            radius: 2.5
                                            color: "#fff6c2"
                                            opacity: spikeBoost > 0.1 ? 0.55 + 0.4 * spikeBoost
                                                                       : (nearPulse ? 0.38 : 0.14)
                                        }
                                    }

                                    Item {
                                        z: 9
                                        visible: isRanvier
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 14
                                        width: 24
                                        height: 22
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: "#ffd54a"
                                            x: 2 + 2 * Math.sin(win.ionClock + axonIndex)
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
                                            color: "#c9a0ff"
                                            x: 7 + 2 * Math.cos(win.ionClock * 0.9)
                                            y: 2 + (nearPulse ? 4 * Math.sin(win.ionClock * 3.2) : 1 * Math.sin(win.ionClock))
                                        }
                                        Rectangle {
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: "#c9a0ff"
                                            x: 16
                                            y: 12 + (nearPulse ? 3 * Math.cos(win.ionClock * 4) : 1 * Math.cos(win.ionClock))
                                        }
                                    }

                                    Label {
                                        z: 10
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 3
                                        text: axonIndex === 0 ? Levels.getLevel(win.currentLevelIndex).startMarker
                                                             : (axonIndex === win.segmentCount - 1 ? "B" : "")
                                        color: "#d4dce8"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Item {
                                        z: 22
                                        visible: win.learningMode && isMyelin
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 1
                                        width: 15
                                        height: 15
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 13
                                            height: 13
                                            radius: 6
                                            color: Qt.rgba(0.08, 0.22, 0.2, 0.9)
                                            border.width: 1
                                            border.color: Qt.rgba(0.35, 0.75, 0.65, 0.45 + 0.35 * Math.sin(win.ionClock * 3.1))
                                        }
                                        Label {
                                            anchors.centerIn: parent
                                            text: "i"
                                            color: "#9af0d8"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.showDidYouKnow("myelin")
                                            onEntered: win.armDykHover("myelin")
                                            onExited: win.disarmDykHover("myelin")
                                        }
                                    }

                                    Item {
                                        z: 22
                                        visible: win.learningMode && isRanvier
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 15
                                        height: 15
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 13
                                            height: 13
                                            radius: 6
                                            color: Qt.rgba(0.28, 0.14, 0.08, 0.9)
                                            border.width: 1
                                            border.color: Qt.rgba(1.0, 0.55, 0.3, 0.5 + 0.35 * Math.sin(win.ionClock * 2.9))
                                        }
                                        Label {
                                            anchors.centerIn: parent
                                            text: "?"
                                            color: "#ffb070"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.showDidYouKnow("ranvier")
                                            onEntered: win.armDykHover("ranvier")
                                            onExited: win.disarmDykHover("ranvier")
                                        }
                                    }

                                    Item {
                                        z: 22
                                        visible: win.learningMode && isRanvier
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 1
                                        width: 12
                                        height: 12
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 9
                                            height: 9
                                            radius: 4
                                            color: Qt.rgba(1, 0.55, 0.25, 0.22 + 0.35 * Math.sin(win.ionClock * 4.2))
                                            border.width: 1
                                            border.color: Qt.rgba(1, 0.65, 0.35, 0.55)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.showDidYouKnow("pump")
                                            onEntered: win.armDykHover("pump")
                                            onExited: win.disarmDykHover("pump")
                                        }
                                    }

                                    MouseArea {
                                        z: 15
                                        anchors.fill: parent
                                        enabled: !isEnd && !win.playbackActive
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            var copy = win.myelin.slice();
                                            while (copy.length < win.segmentCount)
                                                copy.push(false);
                                            copy[axonIndex] = !copy[axonIndex];
                                            copy[axonIndex] = !!copy[axonIndex];
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
                color: "#c9bddc"
                font.bold: true
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 44
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: storyColumn.implicitHeight + 24
            radius: 12
            color: Qt.rgba(0.06, 0.08, 0.14, 0.72)
            border.width: 1
            border.color: Qt.rgba(0.55, 0.6, 0.78, 0.14)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 14
                Label {
                    text: Levels.getLevel(currentLevelIndex).scenarioEmoji || ""
                    font.pixelSize: 34
                    Layout.alignment: Qt.AlignTop
                }
                ColumnLayout {
                    id: storyColumn
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: "Level " + (currentLevelIndex + 1) + " / " + Levels.levelCount()
                                + " — " + Levels.getLevel(currentLevelIndex).title
                        color: "#9ad4ff"
                        font.bold: true
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        text: Levels.getLevel(currentLevelIndex).scenarioText
                        color: "#e2e8f0"
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        lineHeight: 1.18
                    }
                    Label {
                        text: timePressureText
                        wrapMode: Text.WordWrap
                        color: "#d4a574"
                        font.pixelSize: 11
                        font.italic: true
                        Layout.fillWidth: true
                        opacity: 0.75 + 0.25 * Math.abs(Math.sin(ionClock * 1.55))
                    }
                    Label {
                        text: {
                            var L = Levels.getLevel(currentLevelIndex);
                            "Tuning · " + L.startVoltage + " mV · node +" + L.nodePenalty + " · sheath loss "
                                    + Math.abs(L.myelinBoost) + "/seg · Vm brain ≤ " + L.brainActivationThreshold;
                        }
                        color: "#6c7383"
                        font.pixelSize: 9
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Label {
                text: "Paths — tap one to select"
                color: "#7a8699"
                font.pixelSize: 11 }
            Repeater {
                model: activePaths
                delegate: Item {
                    property int pathIdx: index
                    property var pathItem: modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 70

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 12
                        visible: pathIdx === selectedPathIndex
                        color: Qt.rgba(1, 0.52, 0.22, 0.08)
                        border.width: 2
                        border.color: Qt.rgba(1, 0.58, 0.3, 0.72)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: pathIdx === selectedPathIndex ? "#121c2c" : "#0a1018"
                        border.width: 1
                        border.color: pathIdx === selectedPathIndex ? Qt.rgba(1, 0.55, 0.28, 0.35) : "#252d3a"
                        opacity: pathIdx === selectedPathIndex ? 1 : 0.66

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 10
                                Layout.preferredHeight: 10
                                radius: 5
                                color: pathIdx === selectedPathIndex ? "#ff8a4a" : "#3a4555"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Label {
                                    text: pathItem.label
                                    color: "#e8eef5"
                                    font.pixelSize: 12
                                    font.bold: true
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                                Label {
                                    text: pathItem.hint
                                    color: pathIdx === selectedPathIndex ? "#9aa8b8" : "#7d8896"
                                    font.pixelSize: 10
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Row {
                                spacing: 3
                                Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: pathItem.segmentCount
                                    Rectangle {
                                        width: 3
                                        height: 22
                                        radius: 1
                                        color: pathMyelinByte(pathIdx, index) ? "#2f6f5a" : "#c45c28"
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: selectPath(pathIdx)
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: statusLine
            color: "#c9d4e4"
            font.pixelSize: 12
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Button {
                text: win.playbackActive ? "Running..." : "Send Signal"
                highlighted: true
                enabled: !win.playbackActive
                onClicked: {
                    win.stopPlayback();
                    win.lastSim = SignalSim.simulate(win.myelin, win.mergedSim());
                    win.pendingNextLevel = false;
                    if (!win.lastSim.ok) {
                        win.statusLine = Levels.getLevel(win.currentLevelIndex).scenarioText + " — "
                                + win.describeFail(win.lastSim.failReason);
                    } else {
                        win.statusLine = "Propagating…";
                    }
                    win.startSignalPlayback();
                }
            }
            Button {
                text: "Restart level"
                onClicked: win.restartCurrentLevel()
            }
            Button {
                text: "Next level"
                visible: win.pendingNextLevel && win.currentLevelIndex + 1 < Levels.levelCount()
                enabled: !win.playbackActive
                onClicked: win.goNextLevel()
            }
            Button {
                text: win.learningMode ? "Learning: ON" : "Learning: OFF"
                font.pixelSize: 11
                flat: true
                onClicked: {
                    win.learningMode = !win.learningMode;
                    if (!win.learningMode)
                        win.dismissDidYouKnow();
                }
            }
            Label {
                text: "Tap interior segments to toggle myelin (sheath vs node). Send Signal to run the wave."
                color: "#8b95a8"
                font.pixelSize: 10
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

    }

    Drawer {
        id: howDrawer
        edge: Qt.RightEdge
        width: Math.min(440, win.width * 0.48)
        height: win.height
        background: Rectangle {
            color: "#080c16"
            border.width: 1
            border.color: "#223047"
        }

        ScrollView {
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: howDrawer.width - 28
                spacing: 12
                topPadding: 18
                leftPadding: 16
                rightPadding: 16
                bottomPadding: 24

                Label {
                    width: parent.width
                    text: "How Axon Signals Works"
                    wrapMode: Text.WordWrap
                    color: "#e8f6ff"
                    font.pixelSize: 20
                    font.bold: true
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#b8c7dd"
                    font.pixelSize: 12
                    text: "The signal starts strong at a Ranvier node.\n"
                          + "Myelin helps the signal travel farther with less loss.\n"
                          + "Ranvier nodes regenerate the signal.\n"
                          + "Each node activation uses ATP.\n"
                          + "If the signal becomes too weak before the next node, it stops.\n"
                          + "If you use too many nodes, you may run out of ATP.\n"
                          + "Reach the Brain with enough strength to succeed."
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#223047"
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#8fa6c4"
                    font.pixelSize: 11
                    font.italic: true
                    text: "Science note: Real neurons are more complex. This game uses a simplified model inspired by saltatory conduction, where signals travel quickly under myelin and are regenerated at nodes of Ranvier."
                }

                Label {
                    width: parent.width
                    text: "Did you know?"
                    color: "#7ad8ff"
                    font.pixelSize: 13
                    font.bold: true
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#9aa8c0"
                    font.pixelSize: 11
                    text: "Resting membrane potential is typically around -70 mV.\n"
                          + "A neuron usually fires when it reaches about -55 mV.\n"
                          + "Myelin helps signals travel faster and farther.\n"
                          + "Nodes of Ranvier are gaps where the action potential is regenerated."
                }

                Button {
                    text: "Close"
                    onClicked: howDrawer.close()
                }
            }
        }
    }
}
