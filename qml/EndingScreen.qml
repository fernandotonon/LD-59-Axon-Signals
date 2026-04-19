import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    property var levelResultsModel: []
    property bool supportsStory3d: true
    property string brainModelSource: ""
    property real brainSpinClock: 0

    signal restartRequested()
    signal replayRequested()
    signal rulesRequested()

    property bool introStarted: false
    property real glowPulse: 0
    property int brainFrameCount: 24
    property int brainFrameIntervalMs: 980
    property int brainFrame: 0
    property string brainSpriteSource: ""
    property var brainSpriteSources: []
    property var brainSpriteLoadedFlags: ({})
    property int brainSpriteLoadedCount: 0
    property bool brainSpriteReady: false

    function padFrame(v) {
        var n = Math.max(0, Math.floor(v));
        if (n < 10)
            return "00" + n;
        if (n < 100)
            return "0" + n;
        return "" + n;
    }

    function resolveBrainSpriteSource(frameIndex) {
        return Qt.resolvedUrl("../assets/renders/human-brain/human-brain_" + padFrame(frameIndex) + ".png");
    }

    function rebuildBrainSources() {
        var arr = [];
        for (var i = 0; i < brainFrameCount; i++)
            arr.push(resolveBrainSpriteSource(i));
        brainSpriteSources = arr;
    }

    function updateBrainSpriteSource() {
        if (brainSpriteSources.length < brainFrameCount)
            rebuildBrainSources();
        if (brainSpriteSources.length < 1)
            return;
        var idx = brainFrame % brainFrameCount;
        if (idx < 0)
            idx += brainFrameCount;
        if (brainSpriteLoadedFlags[idx] === Image.Ready || brainSpriteSource === "")
            brainSpriteSource = brainSpriteSources[idx];
    }

    function resetBrainSprites() {
        brainFrame = 0;
        brainSpriteSource = resolveBrainSpriteSource(0);
        brainSpriteReady = false;
        brainSpriteLoadedCount = 0;
        brainSpriteLoadedFlags = ({});
        rebuildBrainSources();
    }

    function onBrainSpritePreload(index, status) {
        if (status !== Image.Ready && status !== Image.Error)
            return;
        if (index < 0 || index >= brainFrameCount)
            return;
        if (brainSpriteLoadedFlags.hasOwnProperty(index))
            return;
        var nextFlags = {};
        for (var key in brainSpriteLoadedFlags)
            nextFlags[key] = brainSpriteLoadedFlags[key];
        nextFlags[index] = status;
        brainSpriteLoadedFlags = nextFlags;
        brainSpriteLoadedCount += 1;
        if (status === Image.Ready && index === brainFrame)
            updateBrainSpriteSource();
        if (brainSpriteLoadedCount >= brainFrameCount) {
            brainSpriteReady = true;
            updateBrainSpriteSource();
        }
    }

    function tryAdvanceBrainFrame() {
        if (brainFrameCount < 2)
            return;
        var base = brainFrame;
        for (var i = 1; i <= brainFrameCount; i++) {
            var idx = (base + i) % brainFrameCount;
            if (brainSpriteLoadedFlags[idx] !== Image.Ready)
                continue;
            brainFrame = idx;
            updateBrainSpriteSource();
            return;
        }
    }

    function triggerIntro() {
        introStarted = false;
        introKick.restart();
        resetBrainSprites();
    }

    Component.onCompleted: {
        if (visible)
            triggerIntro();
    }

    onVisibleChanged: {
        if (visible) {
            triggerIntro();
        } else {
            introStarted = false;
        }
    }

    Timer {
        id: introKick
        interval: 35
        repeat: false
        onTriggered: root.introStarted = true
    }

    Timer {
        id: brainSpinTimer
        interval: root.brainFrameIntervalMs
        repeat: true
        running: root.visible
        onTriggered: {
            if (root.brainFrameCount < 2)
                return;
            root.tryAdvanceBrainFrame();
        }
    }

    NumberAnimation on glowPulse {
        from: 0
        to: 1
        duration: 1800
        loops: Animation.Infinite
        easing.type: Easing.InOutSine
        running: root.visible
    }

    Rectangle {
        anchors.fill: parent
        color: "#060a17"
        opacity: 1.0
    }

    Repeater {
        model: 18
        Rectangle {
            width: 180 + (index % 5) * 62
            height: width
            radius: width / 2
            color: Qt.rgba(0.26, 0.44, 0.74, 0.04 + 0.03 * Math.abs(Math.sin(root.brainSpinClock * 0.2 + index)))
            x: ((index * 193) % (root.width + 420)) - 220
            y: ((index * 131) % (root.height + 320)) - 160
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Brain Activated"
            color: "#e7f4ff"
            font.pixelSize: 46
            font.bold: true
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "All signals successfully reached the brain"
            color: "#9fc1dc"
            font.pixelSize: 18
        }

        Item {
            id: brainStage
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(root.width * 0.6, 560)
            Layout.preferredHeight: 260
            scale: root.introStarted ? 1.0 : 0.84
            opacity: root.introStarted ? 1.0 : 0.0

            Behavior on scale {
                NumberAnimation {
                    duration: 520
                    easing.type: Easing.OutBack
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.82
                height: parent.height * 0.9
                radius: height * 0.5
                color: Qt.rgba(0.28, 0.74, 1.0, 0.09 + 0.07 * root.glowPulse)
                border.width: 1
                border.color: Qt.rgba(0.55, 0.86, 1.0, 0.2 + 0.2 * root.glowPulse)
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height * 0.98
                radius: height * 0.5
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.5, 0.84, 1.0, 0.12 + 0.08 * root.glowPulse)
            }

            Image {
                id: brainSpriteImage
                anchors.centerIn: parent
                width: parent.width * 0.64
                height: parent.height * 0.92
                source: root.brainSpriteSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: false
                cache: true
                visible: source !== "" && status !== Image.Error
            }

            Item {
                anchors.fill: parent
                opacity: 0.0
                Repeater {
                    model: root.brainSpriteSources.length
                    Image {
                        width: 1
                        height: 1
                        source: root.brainSpriteSources[index]
                        asynchronous: true
                        cache: true
                        onStatusChanged: root.onBrainSpritePreload(index, status)
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                visible: brainSpriteImage.source !== "" && brainSpriteImage.status !== Image.Ready
                text: "Loading brain visual..."
                color: "#a8c7e8"
                font.pixelSize: 12
            }

            Item {
                anchors.fill: parent
                visible: brainSpriteImage.source === ""
                         || brainSpriteImage.status === Image.Error

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.54
                    height: width
                    radius: width * 0.5
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0.7, 0.9, 1.0, 0.9) }
                        GradientStop { position: 1.0; color: Qt.rgba(0.35, 0.55, 0.85, 0.9) }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0.86, 0.95, 1.0, 0.45)
                    rotation: root.brainSpinClock * 8
                }

                Label {
                    anchors.centerIn: parent
                    text: "BRAIN"
                    color: "#e6f3ff"
                    font.pixelSize: 18
                    font.bold: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            radius: 14
            color: Qt.rgba(0.08, 0.12, 0.2, 0.9)
            border.width: 1
            border.color: Qt.rgba(0.45, 0.7, 1.0, 0.26)
            clip: true

            Label {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.topMargin: 10
                text: "Level Results"
                color: "#9fd9ff"
                font.pixelSize: 14
                font.bold: true
            }

            ListView {
                id: resultsList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 34
                anchors.bottomMargin: 10
                model: root.levelResultsModel
                interactive: false
                clip: true
                spacing: 3

                delegate: Item {
                    width: resultsList.width
                    height: 24
                    property bool shown: false
                    opacity: shown ? 1 : 0
                    x: shown ? 0 : -10

                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Timer {
                        interval: index * 85
                        running: root.introStarted && !parent.shown
                        repeat: false
                        onTriggered: {
                            parent.shown = true;
                        }
                    }

                    Row {
                        anchors.fill: parent
                        spacing: 10

                        Label {
                            width: 28
                            text: modelData.emoji
                            color: "#d8eaff"
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                        }
                        Label {
                            width: Math.max(120, resultsList.width - 292)
                            text: modelData.title
                            color: "#e3edf8"
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        Label {
                            width: 20
                            text: modelData.success ? "\u2713" : "-"
                            color: modelData.success ? "#7bf5ce" : "#ffb394"
                            font.pixelSize: 15
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                        Label {
                            width: 120
                            text: "Strength: " + modelData.strength
                            color: "#b8cce2"
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                        Label {
                            width: 72
                            text: "ATP: " + modelData.atp
                            color: "#b8cce2"
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 98
            radius: 14
            color: Qt.rgba(0.08, 0.11, 0.19, 0.86)
            border.width: 1
            border.color: Qt.rgba(0.42, 0.66, 0.95, 0.23)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Repeater {
                    model: root.levelResultsModel
                    delegate: Rectangle {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        radius: 10
                        color: hovered ? Qt.rgba(0.14, 0.22, 0.36, 0.95) : Qt.rgba(0.09, 0.15, 0.27, 0.9)
                        border.width: 1
                        border.color: hovered ? Qt.rgba(0.62, 0.86, 1.0, 0.7) : Qt.rgba(0.48, 0.62, 0.86, 0.35)
                        property bool hovered: false
                        scale: hovered ? 1.03 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 10
                            spacing: 2
                            Item {
                                width: parent.width
                                height: 46
                                Image {
                                    id: levelThumb
                                    anchors.centerIn: parent
                                    width: parent.width * 0.82
                                    height: parent.height
                                    source: modelData.sprite0 ? modelData.sprite0 : ""
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                    cache: true
                                    visible: source !== "" && status !== Image.Error
                                }
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.emoji
                                    color: "#eaf3ff"
                                    font.pixelSize: 20
                                    visible: !levelThumb.visible
                                }
                            }
                            Label {
                                text: modelData.shortTitle
                                color: "#b8cfe6"
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            Button {
                text: "Restart Game"
                onClicked: root.restartRequested()
            }
            Button {
                text: "Replay Levels"
                onClicked: root.replayRequested()
            }
            Button {
                text: "View Rules"
                onClicked: root.rulesRequested()
            }
        }

        Item { Layout.fillHeight: true }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "3D assets powered by QtMesh"
            color: Qt.rgba(0.68, 0.78, 0.92, 0.6)
            font.pixelSize: 10
        }
    }
}
