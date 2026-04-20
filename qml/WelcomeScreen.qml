import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent

    property bool active: true
    property string coverSource: ""
    property real pulseClock: 0
    property bool musicEnabled: true
    property bool sfxEnabled: true
    property var howItWorksLines: []

    signal startRequested()
    signal musicToggleRequested()
    signal sfxToggleRequested()

    property bool introVisible: false
    property bool howPanelOpen: false

    function bullets(lines) {
        var out = "";
        for (var i = 0; i < lines.length; i++) {
            out += "• " + lines[i];
            if (i < lines.length - 1)
                out += "\n";
        }
        return out;
    }

    visible: opacity > 0.01
    enabled: opacity > 0.05
    opacity: active ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutCubic
        }
    }

    onActiveChanged: {
        if (active) {
            introVisible = false;
            howPanelOpen = false;
            introKick.restart();
        }
    }

    Component.onCompleted: {
        if (active)
            introKick.restart();
    }

    Timer {
        id: introKick
        interval: 40
        repeat: false
        onTriggered: root.introVisible = true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#080d20" }
            GradientStop { position: 0.55; color: "#0b1232" }
            GradientStop { position: 1.0; color: "#110c24" }
        }
    }

    Image {
        anchors.fill: parent
        source: root.coverSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: true
        opacity: status === Image.Ready ? 0.9 : 0.0
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.05, 0.12, 0.56)
    }

    Repeater {
        model: 22
        Rectangle {
            width: 2 + (index % 4)
            height: width
            radius: width / 2
            color: Qt.rgba(0.59, 0.84, 1.0, 0.1 + 0.15 * Math.abs(Math.sin(root.pulseClock * 0.8 + index)))
            x: ((index * 103) % (root.width + 180)) - 90
            y: ((index * 77) % (root.height + 140)) - 70
        }
    }

    Item {
        id: centerStage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 36, 640)
        height: Math.min(parent.height - 80, 520)
        scale: root.introVisible ? 1.0 : 0.95
        opacity: root.introVisible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutBack
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.rgba(0.04, 0.08, 0.18, 0.78)
            border.width: 1
            border.color: Qt.rgba(0.52, 0.78, 1.0, 0.32)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 18
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0.67, 0.9, 1.0, 0.12 + 0.08 * Math.abs(Math.sin(root.pulseClock * 1.6)))
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 104

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Axon Signals"
                    color: Qt.rgba(0.39, 0.86, 1.0, 0.42)
                    font.pixelSize: 58
                    font.bold: true
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: "Axon Signals"
                    color: "#e9f7ff"
                    font.pixelSize: 56
                    font.bold: true
                }
            }

            Label {
                Layout.fillWidth: true
                text: "Think Fast. Send the Signal."
                color: "#b8d9f5"
                font.pixelSize: 21
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 250
                Layout.preferredHeight: 52
                text: "Start Game"
                onClicked: root.startRequested()
                background: Rectangle {
                    radius: 12
                    color: "#2d9ad8"
                    border.width: 1
                    border.color: "#9be3ff"
                }
                contentItem: Label {
                    text: parent.text
                    color: "#f1fbff"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 250
                Layout.preferredHeight: 44
                text: "How It Works"
                onClicked: root.howPanelOpen = true
                background: Rectangle {
                    radius: 11
                    color: "#20344b"
                    border.width: 1
                    border.color: "#7fb7e2"
                }
                contentItem: Label {
                    text: parent.text
                    color: "#dbecff"
                    font.pixelSize: 15
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                Button {
                    text: root.musicEnabled ? "Music ON" : "Music OFF"
                    onClicked: root.musicToggleRequested()
                    background: Rectangle {
                        radius: 9
                        color: "#223245"
                        border.width: 1
                        border.color: "#7ea4ca"
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
                    text: root.sfxEnabled ? "SFX ON" : "SFX OFF"
                    onClicked: root.sfxToggleRequested()
                    background: Rectangle {
                        radius: 9
                        color: "#223245"
                        border.width: 1
                        border.color: "#7ea4ca"
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
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.howPanelOpen
        z: 50

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.03, 0.08, 0.78)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.howPanelOpen = false
        }

        Rectangle {
            width: Math.min(parent.width - 36, 540)
            height: Math.min(parent.height - 36, 420)
            anchors.centerIn: parent
            radius: 16
            color: "#0c1528"
            border.width: 1
            border.color: "#3e6f99"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }

            Column {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                Label {
                    width: parent.width
                    text: "How Axon Signals Works"
                    color: "#e4f4ff"
                    font.pixelSize: 24
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Label {
                    width: parent.width
                    text: root.bullets(root.howItWorksLines)
                    color: "#c3d5ea"
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                }

                Label {
                    width: parent.width
                    text: "Reach the brain before the signal fades. Balance strength and energy."
                    color: "#96adc9"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: 1
                    height: 8
                }

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 160
                    text: "Close"
                    onClicked: root.howPanelOpen = false
                }
            }
        }
    }
}
