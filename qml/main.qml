// Axon Signals - saltatory conduction puzzle (signal strength + ATP). Web Dojo: sibling js/signalSim.js.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/signalSim.js" as SignalSim
import "js/levels.js" as Levels

ApplicationWindow {
    id: win
    visible: true
    width: 1320
    height: 920
    title: "Axon Signals"
    color: "#060814"

    property int segmentCount: 26
    property int cellOuterWidth: 52
    property int axonSpacing: 10
    readonly property int axonRowHeight: 236
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
    property bool runAttempted: false

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
    readonly property var hudCardConfig: ({
        "signal": { colorA: "#56d7ff", colorB: "#88f6ff" },
        "atp": { colorA: "#8af6c7", colorB: "#cbffe9" },
        "goal": { colorA: "#ffb278", colorB: "#ffdcb3" }
    })
    readonly property var levelMissionMeta: ({
        1: {
            visualLabel: "ICE CREAM ALERT",
            urgency: "Send the signal to your brain before the truck drives away!",
            consequence: "If the signal lags, dessert is gone."
        },
        2: {
            visualLabel: "HEAT WARNING",
            urgency: "Your hand is still on the heat - react quickly!",
            consequence: "If you fail, your hand stays on the hot pan."
        },
        3: {
            visualLabel: "STEP DANGER",
            urgency: "Your foot is about to step on a nail - react now!",
            consequence: "If the signal fades, you step right onto the nail."
        },
        4: {
            visualLabel: "INCOMING FAST",
            urgency: "A baseball is flying toward you - signal the brain before impact!",
            consequence: "Slow signaling means taking a direct hit."
        },
        5: {
            visualLabel: "SPOILED FOOD",
            urgency: "React before you eat it.",
            consequence: "A delayed response can mean food poisoning."
        }
    })
    readonly property var howItWorksLines: [
        "Myelin protects the signal and reduces loss.",
        "Nodes of Ranvier regenerate the signal.",
        "Each node activation costs ATP.",
        "Reach the brain with enough strength to succeed."
    ]
    readonly property var didYouKnowLines: [
        "Neurons rest at about -70 mV.",
        "Many neurons fire around -55 mV.",
        "Myelin helps signals travel faster and farther.",
        "Nodes of Ranvier are gaps where the signal is regenerated."
    ]
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

    function currentLevelData() {
        return Levels.getLevel(currentLevelIndex);
    }

    function missionMeta() {
        var L = currentLevelData();
        return levelMissionMeta[L.id] ? levelMissionMeta[L.id] : {
            visualLabel: "NEURAL RESPONSE",
            urgency: L.timePressureLabel,
            consequence: L.failFeedback
        };
    }

    function listToBullets(lines) {
        var out = "";
        for (var i = 0; i < lines.length; i++) {
            out += "• " + lines[i];
            if (i < lines.length - 1)
                out += "\n";
        }
        return out;
    }

    function isSignalSuccessful() {
        return runAttempted && !playbackActive && lastSim.ok;
    }

    function isSignalFailed() {
        return runAttempted && !playbackActive && !lastSim.ok;
    }

    function resultTitleText() {
        if (playbackActive)
            return "Signal in Transit";
        if (!runAttempted)
            return "Awaiting Signal";
        return lastSim.ok ? "Signal Reached Brain" : "Signal Collapsed";
    }

    function resultBodyText() {
        if (!runAttempted)
            return "Send Signal to run this mission and see the outcome.";
        if (playbackActive)
            return "The pulse is propagating through the axon...";
        if (lastSim.ok) {
            var thr = (lastSim.config && lastSim.config.brainActivationThreshold !== undefined)
                    ? Math.round(lastSim.config.brainActivationThreshold) : 40;
            return currentLevelData().successFeedback + "\nStrength "
                    + Math.round(lastSim.signalStrength) + " (needed >= " + thr + ")";
        }
        return describeFail(lastSim.failReason) + ".\n" + currentLevelData().failFeedback;
    }

    function resultAccentColor() {
        if (isSignalSuccessful())
            return "#49e7d2";
        if (isSignalFailed())
            return "#ff8b5a";
        return "#8cb2d6";
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
        runAttempted = false;
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
        runAttempted = false;
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
        runAttempted = false;
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
            runAttempted = false;
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
            GradientStop { position: 0.0; color: "#060b1f" }
            GradientStop { position: 0.5; color: "#0b1230" }
            GradientStop { position: 1.0; color: "#140c28" }
        }
    }

    Repeater {
        model: 16
        Rectangle {
            width: 180 + (index % 5) * 60
            height: width
            radius: width / 2
            color: Qt.rgba(0.2, 0.35, 0.6, 0.05 + 0.03 * Math.abs(Math.sin(win.ionClock * 0.32 + index)))
            x: ((index * 197) % (win.width + 420)) - 200
            y: ((index * 139) % (win.height + 300)) - 130
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
        anchors.topMargin: 56
        width: Math.min(480, parent.width - 36)
        height: Math.min(140, Math.max(52, dykBody.implicitHeight + 28))
        radius: 12
        color: "#0b162b"
        border.width: 1
        border.color: Qt.rgba(0.35, 0.85, 1.0, 0.55)
        opacity: 0.97

        Rectangle {
            z: 0
            anchors.fill: parent
            anchors.margins: 1
            radius: 11
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
            anchors.rightMargin: 8
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
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 18, 1560)
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                radius: 12
                color: Qt.rgba(0.05, 0.1, 0.2, 0.84)
                border.width: 1
                border.color: Qt.rgba(0.45, 0.67, 1.0, 0.2)
                Layout.preferredHeight: 62
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Label {
                        text: "Axon Signals"
                        color: "#ecf5ff"
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Button {
                        text: "Neuron rules"
                        flat: true
                        font.pixelSize: 12
                        onClicked: howDrawer.open()
                        contentItem: Label {
                            text: parent.text
                            color: "#9fd4ff"
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            RowLayout {
                spacing: 8
                Repeater {
                    model: [
                        { label: "Signal", tone: "signal" },
                        { label: "ATP", tone: "atp" },
                        { label: "Goal", tone: "goal" }
                    ]
                    delegate: Rectangle {
                        readonly property var toneCfg: win.hudCardConfig[modelData.tone]
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 62
                        radius: 11
                        color: Qt.rgba(0.07, 0.11, 0.2, 0.9)
                        border.width: 1
                        border.color: Qt.rgba(0.55, 0.6, 0.8, 0.23)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 8
                            width: 3
                            radius: 2
                            color: toneCfg.colorA
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            spacing: 2
                            Label {
                                text: modelData.label
                                color: "#9caec4"
                                font.pixelSize: 10
                            }
                            Label {
                                text: {
                                    if (index === 0)
                                        return "" + Math.round(win.playbackActive ? win.displaySignalStrength : win.lastSim.signalStrength);
                                    if (index === 1)
                                        return "" + (win.playbackActive ? win.displayAtp : win.lastSim.atp);
                                    return ">= " + ((win.lastSim.config && win.lastSim.config.brainActivationThreshold !== undefined)
                                            ? Math.round(win.lastSim.config.brainActivationThreshold) : 40);
                                }
                                color: toneCfg.colorB
                                font.pixelSize: 18
                                font.bold: true
                            }
                        }
                    }
                }

            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 318
            radius: 16
            color: Qt.rgba(0.05, 0.09, 0.18, 0.86)
            border.width: 1
            border.color: Qt.rgba(0.45, 0.62, 0.95, 0.24)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 210
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.08, 0.13, 0.25, 0.95)
                    border.width: 1
                    border.color: Qt.rgba(0.44, 0.66, 1.0, 0.22)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 8
                        radius: 9
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0.2, 0.35, 0.75, 0.45) }
                            GradientStop { position: 1.0; color: Qt.rgba(0.1, 0.13, 0.24, 0.7) }
                        }
                        border.width: 1
                        border.color: Qt.rgba(0.66, 0.83, 1.0, 0.24)
                    }

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        text: Levels.getLevel(currentLevelIndex).scenarioEmoji || "?"
                        font.pixelSize: 64
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        text: missionMeta().visualLabel
                        color: "#d9ebff"
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(0.08, 0.12, 0.2, 0.9)
                    border.width: 1
                    border.color: Qt.rgba(0.55, 0.72, 1.0, 0.2)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Label {
                            width: parent.width
                            text: "Level " + (currentLevelIndex + 1) + " / " + Levels.levelCount()
                                    + " - " + Levels.getLevel(currentLevelIndex).title
                            color: "#9fd9ff"
                            font.pixelSize: 16
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            width: parent.width
                            text: Levels.getLevel(currentLevelIndex).scenarioText
                            color: "#e6eef9"
                            font.pixelSize: 17
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: parent.width
                            height: urgencyText.implicitHeight + 14
                            radius: 8
                            color: Qt.rgba(0.65, 0.34, 0.2, 0.16 + 0.05 * Math.abs(Math.sin(win.ionClock * 1.6)))
                            border.width: 1
                            border.color: Qt.rgba(1.0, 0.62, 0.38, 0.34)

                            Label {
                                id: urgencyText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: missionMeta().urgency
                                color: "#ffc99a"
                                font.pixelSize: 12
                                font.bold: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Label {
                            width: parent.width
                            text: "Consequence: " + missionMeta().consequence
                            color: "#9eaac0"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 326
                    Layout.fillHeight: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: Qt.rgba(0.08, 0.12, 0.2, 0.9)
                        border.width: 1
                        border.color: Qt.rgba(0.43, 0.8, 1.0, 0.22)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            Label {
                                width: parent.width
                                text: "How it works"
                                color: "#8fe3ff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Label {
                                width: parent.width
                                text: win.listToBullets(win.howItWorksLines)
                                color: "#c2d2e8"
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                lineHeight: 1.15
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: Qt.rgba(0.1, 0.11, 0.19, 0.9)
                        border.width: 1
                        border.color: Qt.rgba(0.7, 0.68, 1.0, 0.22)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6
                            Label {
                                width: parent.width
                                text: "Did you know?"
                                color: "#c8b7ff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Label {
                                width: parent.width
                                text: win.listToBullets(win.didYouKnowLines)
                                color: "#c6cce0"
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                lineHeight: 1.15
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: win.axonRowHeight + 170
            radius: 18
            color: Qt.rgba(0.04, 0.09, 0.16, 0.86)
            border.width: 1
            border.color: Qt.rgba(0.45, 0.72, 1.0, 0.22)

            Repeater {
                model: 20
                Rectangle {
                    width: 2 + (index % 3)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0.53, 0.78, 1.0, 0.07 + 0.08 * Math.abs(Math.sin(win.ionClock * 0.9 + index)))
                    x: 18 + ((index * 91) % (parent.width - 40))
                    y: 16 + ((index * 57) % (parent.height - 32))
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width - 80, 1200)
                height: win.axonRowHeight + 72
                radius: height * 0.5
                color: Qt.rgba(0.25, 0.6, 1.0, 0.08)
                border.width: 1
                border.color: Qt.rgba(0.56, 0.82, 1.0, 0.12)
            }

            Item {
                id: axonBand
                anchors.fill: parent
                anchors.margins: 16

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(0.03, 0.06, 0.12, 0.42)
                    border.width: 1
                    border.color: Qt.rgba(0.55, 0.58, 0.78, 0.14)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    height: 34
                    radius: 9
                    color: Qt.rgba(0.12, 0.19, 0.28, 0.88)
                    border.width: 1
                    border.color: Qt.rgba(0.6, 0.86, 1.0, 0.3)
                    Label {
                        anchors.centerIn: parent
                        text: Levels.getLevel(currentLevelIndex).startOrgan + " (" + Levels.getLevel(currentLevelIndex).startMarker + ")"
                        color: "#cde6ff"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 74
                    height: 34
                    radius: 9
                    color: Qt.rgba(0.21, 0.15, 0.29, 0.9)
                    border.width: 1
                    border.color: Qt.rgba(0.82, 0.68, 1.0, 0.28)
                    Label {
                        anchors.centerIn: parent
                        text: "Brain (B)"
                        color: "#ebdbff"
                        font.pixelSize: 10
                        font.bold: true
                    }
                }

                Flickable {
                    id: axonFlick
                    anchors.fill: parent
                    anchors.topMargin: 28
                    anchors.bottomMargin: 28
                    anchors.leftMargin: 88
                    anchors.rightMargin: 88
                    contentWidth: axonRow.width
                    contentHeight: height
                    clip: true

                    Row {
                        id: axonRow
                        spacing: win.axonSpacing
                        height: win.axonRowHeight
                        x: Math.max(0, (axonFlick.width - width) / 2)
                        y: Math.max(0, (axonFlick.height - height) / 2)

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
                                    width: parent.width * 2.7
                                    height: parent.height * 0.95
                                    visible: nearPulse
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.98
                                        height: parent.height * 0.88
                                        radius: width * 0.5
                                        color: Qt.rgba(0.32, 0.74, 1.0, (0.08 + 0.44 * parent.parent.normStrength) * parent.parent.pulseFlicker)
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.58
                                        height: parent.height * 0.62
                                        radius: width * 0.5
                                        color: Qt.rgba(0.88, 0.96, 1.0, (0.22 + 0.68 * parent.parent.normStrength) * parent.parent.pulseFlicker)
                                        border.width: 2
                                        border.color: Qt.rgba(0.45, 0.88, 1.0, 0.95)
                                    }
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.24
                                        height: parent.height * 0.28
                                        radius: width * 0.5
                                        color: Qt.rgba(1, 1, 1, 0.42 + 0.55 * parent.parent.normStrength)
                                    }
                                }

                                Rectangle {
                                    z: 0
                                    visible: isMyelin
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 36
                                    height: 164
                                    radius: 18
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#36645f" }
                                        GradientStop { position: 1.0; color: "#234640" }
                                    }
                                    border.width: 1
                                    border.color: "#1d3c38"
                                }

                                Rectangle {
                                    z: 0
                                    visible: isRanvier
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    height: 174
                                    radius: 20
                                    color: "#291d18"
                                    border.width: 2
                                    border.color: Qt.rgba(1, 0.48, 0.18, 0.42 + 0.4 * spikeBoost + (nearPulse ? 0.22 : 0))
                                }
                                Rectangle {
                                    z: 1
                                    visible: isRanvier
                                    anchors.centerIn: parent
                                    width: 54
                                    height: 186
                                    radius: 27
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 0.42, 0.15, 0.14 + 0.3 * spikeBoost + 0.22 * nearPulse)
                                }
                                Rectangle {
                                    z: 2
                                    visible: isRanvier
                                    anchors.centerIn: parent
                                    width: 28
                                    height: 140
                                    radius: 14
                                    color: "transparent"
                                    border.width: 3
                                    border.color: Qt.rgba(1, 0.52, 0.22, 0.52 + 0.38 * spikeBoost + (nearPulse ? 0.2 : 0))
                                }

                                Rectangle {
                                    z: 3
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 5
                                    height: isMyelin ? 92 : 110
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
                                    width: 28
                                    height: 28
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
                                        x: 15
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

                Item {
                    anchors.left: parent.left
                    anchors.leftMargin: 88
                    anchors.top: parent.top
                    width: 178
                    height: 52
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.rgba(0.1, 0.22, 0.2, 0.84)
                        border.width: 1
                        border.color: Qt.rgba(0.53, 0.96, 0.82, 0.28)
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Myelin"
                        color: "#a8ffe1"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 86
                        anchors.verticalCenter: parent.verticalCenter
                        width: 80
                        height: 2
                        radius: 1
                        color: Qt.rgba(0.56, 0.96, 0.82, 0.5)
                        rotation: 22
                    }
                }

                Item {
                    anchors.right: parent.right
                    anchors.rightMargin: 88
                    anchors.top: parent.top
                    width: 204
                    height: 52
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.rgba(0.24, 0.15, 0.11, 0.86)
                        border.width: 1
                        border.color: Qt.rgba(1.0, 0.66, 0.42, 0.28)
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Node of Ranvier"
                        color: "#ffc99a"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 70
                        height: 2
                        radius: 1
                        color: Qt.rgba(1.0, 0.68, 0.43, 0.5)
                        rotation: -18
                    }
                }

                Item {
                    anchors.right: parent.right
                    anchors.rightMargin: 116
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: 170
                    height: 44
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: Qt.rgba(0.21, 0.17, 0.3, 0.86)
                        border.width: 1
                        border.color: Qt.rgba(0.82, 0.72, 1.0, 0.26)
                    }
                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Na+/K+ Pump"
                        color: "#dfc6ff"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 108
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56
                        height: 2
                        radius: 1
                        color: Qt.rgba(0.82, 0.72, 1.0, 0.5)
                        rotation: 14
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 246
            spacing: 10

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 290
                radius: 14
                color: Qt.rgba(0.08, 0.11, 0.18, 0.88)
                border.width: 1
                border.color: Qt.rgba(0.56, 0.64, 0.86, 0.2)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Label {
                        width: parent.width
                        text: "Mission Snapshot"
                        color: "#9fd6ff"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Label {
                        width: parent.width
                        text: Levels.getLevel(currentLevelIndex).scenarioText
                        color: "#d9e7f8"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        text: missionMeta().urgency
                        color: "#ffc28f"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        text: "If you fail: " + missionMeta().consequence
                        color: "#9faec3"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Qt.rgba(0.07, 0.11, 0.2, 0.9)
                border.width: 1
                border.color: Qt.rgba(0.46, 0.74, 1.0, 0.23)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Label {
                        text: "Paths - tap one to select"
                        color: "#a7d5ff"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    Repeater {
                        model: activePaths
                        delegate: Item {
                            property int pathIdx: index
                            property var pathItem: modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: pathIdx === selectedPathIndex ? Qt.rgba(0.09, 0.2, 0.33, 0.95) : Qt.rgba(0.05, 0.09, 0.16, 0.8)
                                border.width: pathIdx === selectedPathIndex ? 2 : 1
                                border.color: pathIdx === selectedPathIndex
                                              ? Qt.rgba(0.45, 0.86, 1.0, 0.9)
                                              : Qt.rgba(0.42, 0.5, 0.64, 0.38)
                                Rectangle {
                                    visible: pathIdx === selectedPathIndex
                                    anchors.fill: parent
                                    anchors.margins: -2
                                    radius: 11
                                    color: "transparent"
                                    border.width: 2
                                    border.color: Qt.rgba(0.45, 0.86, 1.0, 0.25)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 11
                                        Layout.preferredHeight: 11
                                        radius: 5
                                        color: pathIdx === selectedPathIndex ? "#64ecff" : "#3a4555"
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
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
                                            color: pathIdx === selectedPathIndex ? "#acd5f0" : "#7d8896"
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
                                                color: pathMyelinByte(pathIdx, index) ? "#3e8f76" : "#d96b37"
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
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 330
                radius: 14
                color: Qt.rgba(0.08, 0.11, 0.18, 0.9)
                border.width: 1
                border.color: Qt.rgba(0.56, 0.64, 0.86, 0.2)

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 5
                    radius: 3
                    color: win.resultAccentColor()
                    opacity: 0.75
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Label {
                        width: parent.width
                        text: "Outcome"
                        color: "#b5cbe0"
                        font.pixelSize: 11
                    }
                    Label {
                        width: parent.width
                        text: win.resultTitleText()
                        color: win.resultAccentColor()
                        font.pixelSize: 18
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        text: win.resultBodyText()
                        color: "#d9e5f3"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        text: "Weakest strength " + Math.round(lastSim.lowestSignalStrength !== undefined
                                ? lastSim.lowestSignalStrength : lastSim.signalStrength)
                                + " | ATP left " + (win.playbackActive ? win.displayAtp : win.lastSim.atp)
                        color: "#94a8bf"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        width: parent.width
                        text: statusLine
                        color: "#9cabbe"
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            radius: 12
            color: Qt.rgba(0.05, 0.1, 0.2, 0.9)
            border.width: 1
            border.color: Qt.rgba(0.45, 0.62, 0.95, 0.24)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Button {
                    text: win.playbackActive ? "Running..." : "Send Signal"
                    enabled: !win.playbackActive
                    onClicked: {
                        win.runAttempted = true;
                        win.stopPlayback();
                        win.lastSim = SignalSim.simulate(win.myelin, win.mergedSim());
                        win.pendingNextLevel = false;
                        if (!win.lastSim.ok) {
                            win.statusLine = Levels.getLevel(win.currentLevelIndex).scenarioText + " - "
                                    + win.describeFail(win.lastSim.failReason);
                        } else {
                            win.statusLine = "Propagating...";
                        }
                        win.startSignalPlayback();
                    }
                    background: Rectangle {
                        radius: 9
                        color: parent.enabled ? "#2f9fe0" : "#2a4054"
                        border.width: 1
                        border.color: parent.enabled ? "#8de4ff" : "#4b6377"
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "#eef8ff"
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Restart level"
                    onClicked: win.restartCurrentLevel()
                    background: Rectangle {
                        radius: 9
                        color: parent.enabled ? "#253a55" : "#223245"
                        border.width: 1
                        border.color: parent.enabled ? "#7ba4d1" : "#51657a"
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "#e0efff"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Next level"
                    visible: win.pendingNextLevel && win.currentLevelIndex + 1 < Levels.levelCount()
                    enabled: !win.playbackActive
                    onClicked: win.goNextLevel()
                    background: Rectangle {
                        radius: 9
                        color: parent.enabled ? "#1f7f71" : "#2d524d"
                        border.width: 1
                        border.color: parent.enabled ? "#77f3d5" : "#5d8d86"
                    }
                    contentItem: Label {
                        text: parent.text
                        color: "#e8fffa"
                        font.pixelSize: 12
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Label {
                    text: "Hint: tap interior segments to toggle myelin and shape the signal path."
                    color: "#8ea4be"
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
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
                    text: win.listToBullets(win.howItWorksLines)
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
                    text: win.listToBullets(win.didYouKnowLines)
                }

                Button {
                    text: "Close"
                    onClicked: howDrawer.close()
                }
            }
        }
    }
}
