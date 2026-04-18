import QtQuick 2.15

// Small info dot: click (primary) or brief hover delay opens the host tooltip. z above axon toggles.
Item {
    id: root
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
        color: glowColor
        opacity: 0.12 + 0.14 * Math.abs(Math.sin(clock * 2.8))
    }

    Rectangle {
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: "#0f1828"
        border.width: 1
        border.color: Qt.lighter(glowColor, 1.25)
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
        id: hoverOpenDelay
        interval: 480
        repeat: false
        onTriggered: {
            if (root.lit)
                root.tipOpenRequested(root.topicId, root);
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
            hoverOpenDelay.stop();
            if (root.lit)
                root.tipOpenRequested(root.topicId, root);
        }
        onEntered: {
            if (root.lit)
                hoverOpenDelay.restart();
        }
        onExited: hoverOpenDelay.stop()
    }
}
