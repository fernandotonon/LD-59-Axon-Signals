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

    function triggerIntro() {
        introStarted = false;
        introKick.restart();
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
        opacity: 0.98
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

            Loader {
                id: ending3dLoader
                anchors.fill: parent
                active: root.supportsStory3d
                source: "StoryVisual3D.qml"
            }

            Binding {
                target: ending3dLoader.item
                property: "modelSource"
                value: root.brainModelSource
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "modelScale"
                value: 34
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "modelRotX"
                value: -12
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "modelRotY"
                value: 18
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "modelRotZ"
                value: 0
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "modelPosY"
                value: -22
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "camY"
                value: 20
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "camZ"
                value: 150
                when: ending3dLoader.status === Loader.Ready
            }
            Binding {
                target: ending3dLoader.item
                property: "spinClock"
                value: root.brainSpinClock
                when: ending3dLoader.status === Loader.Ready
            }

            Item {
                anchors.fill: parent
                visible: !root.supportsStory3d
                         || ending3dLoader.status !== Loader.Ready
                         || !ending3dLoader.item.modelReady

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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Label {
                    text: "Level Results"
                    color: "#9fd9ff"
                    font.pixelSize: 14
                    font.bold: true
                }

                Repeater {
                    model: root.levelResultsModel
                    delegate: RowLayout {
                        id: summaryRow
                        Layout.fillWidth: true
                        spacing: 10
                        opacity: 0
                        y: 8

                        states: State {
                            name: "shown"
                            when: root.introStarted
                            PropertyChanges {
                                target: summaryRow
                                opacity: 1
                                y: 0
                            }
                        }

                        transitions: Transition {
                            from: ""
                            to: "shown"
                            SequentialAnimation {
                                PauseAnimation { duration: index * 85 }
                                ParallelAnimation {
                                    NumberAnimation { target: summaryRow; property: "opacity"; duration: 240; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: summaryRow; property: "y"; duration: 240; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Label {
                            text: modelData.emoji
                            color: "#d8eaff"
                            font.pixelSize: 16
                            Layout.preferredWidth: 28
                        }

                        Label {
                            text: modelData.title
                            color: "#e3edf8"
                            font.pixelSize: 13
                            Layout.fillWidth: true
                        }

                        Label {
                            text: modelData.success ? "\u2713" : "-"
                            color: modelData.success ? "#7bf5ce" : "#ffb394"
                            font.pixelSize: 15
                            font.bold: true
                            Layout.preferredWidth: 20
                        }

                        Label {
                            text: "Strength: " + modelData.strength
                            color: "#b8cce2"
                            font.pixelSize: 12
                            Layout.preferredWidth: 120
                        }

                        Label {
                            text: "ATP: " + modelData.atp
                            color: "#b8cce2"
                            font.pixelSize: 12
                            Layout.preferredWidth: 72
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
                            Label {
                                text: modelData.emoji
                                color: "#eaf3ff"
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
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
