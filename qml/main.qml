// Axon Signals — Ludum Dare style prototype (theme: "Signal").
// 2D editing configures myelin; 3D playback visualizes saltatory conduction.
// Clayground / template: point the engine entry at this file (qml/main.qml in the resource tree).
// 3D phase uses perspective projection on Canvas (no Qt3D dependency) so desktop Qt Quick builds stay light.

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "js/signalSim.js" as SignalSim

ApplicationWindow {
    id: win
    visible: true
    width: 960
    height: 600
    title: "Axon Signals — LD Prototype"
    color: "#070910"

    property int segmentCount: 26
    property var myelin: []
    property var lastSim: ({ ok: false, energy: 0, failReason: "", steps: [], nodes: [] })
    property string statusLine: "Click axon segments to toggle myelin vs exposed (node) stretches."
    property bool showPlayback: false

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

    function resetLevel() {
        myelin = defaultMyelinPattern();
        refreshPreview();
        statusLine = "Foot to brain: click segments to toggle myelin — exposed gaps become nodes of Ranvier.";
    }

    function refreshPreview() {
        lastSim = SignalSim.simulate(myelin, null);
    }

    Component.onCompleted: resetLevel()

    onMyelinChanged: refreshPreview()

    function describeFail(code) {
        if (code === "jump_too_far")
            return "saltation gap exceeded the node's reach.";
        if (code === "out_of_energy")
            return "the axon ran out of electrochemical budget.";
        if (code === "no_path")
            return "no valid node layout.";
        return "signal dissipated.";
    }

    // --- 2D editor ---
    Item {
        id: editorLayer
        anchors.fill: parent
        visible: !showPlayback

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#05060c" }
                GradientStop { position: 1.0; color: "#0c1220" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 18

                Label {
                    text: "Axon Signals"
                    color: "#e8f6ff"
                    font.pixelSize: 26
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Label {
                    text: "Energy (preview): <b>" + Math.round(lastSim.energy * 10) / 10 + "</b>"
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

            RowLayout {
                spacing: 10
                Label {
                    text: "Foot"
                    color: "#5bd0ff"
                    font.bold: true
                    font.pixelSize: 12
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 110
                    radius: 10
                    color: "#101522"
                    border.color: "#223047"
                    border.width: 1

                    Row {
                        id: axonRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: win.segmentCount

                            Rectangle {
                                width: 28
                                height: 72
                                radius: 6
                                color: {
                                    if (index === 0 || index === win.segmentCount - 1)
                                        return "#2a3040";
                                    return win.myelin[index] ? "#1f6b3a" : "#3a1a12";
                                }
                                border.width: nodeHighlight ? 2 : 1
                                border.color: nodeHighlight ? "#ff9a3c" : "#182030"

                                readonly property bool nodeHighlight: {
                                    var nodes = SignalSim.buildNodeIndices(win.myelin);
                                    for (var i = 0; i < nodes.length; i++) {
                                        if (nodes[i] === index)
                                            return true;
                                    }
                                    return false;
                                }

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    text: index === 0 ? "F" : (index === win.segmentCount - 1 ? "B" : "")
                                    color: "#8fd7ff"
                                    font.pixelSize: 10
                                }
                            }
                        }

                        MouseArea {
                            z: 2
                            anchors.fill: parent
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor

                            function indexAt(mouseX) {
                                var s = axonRow.spacing;
                                var w = 28;
                                var x = mouseX;
                                var acc = 0;
                                for (var i = 0; i < win.segmentCount; i++) {
                                    if (x >= acc && x < acc + w)
                                        return i;
                                    acc += w + s;
                                }
                                return -1;
                            }

                            onClicked: {
                                var idx = indexAt(mouseX);
                                if (idx <= 0 || idx >= win.segmentCount - 1)
                                    return;
                                var copy = win.myelin.slice();
                                copy[idx] = !copy[idx];
                                win.myelin = copy;
                            }
                        }
                    }
                }

                Label {
                    text: "Brain"
                    color: "#d49bff"
                    font.bold: true
                    font.pixelSize: 12
                }
            }

            RowLayout {
                spacing: 12

                Button {
                    text: "Send Signal"
                    highlighted: true
                    onClicked: {
                        win.lastSim = SignalSim.simulate(win.myelin, null);
                        playbackLoader.myelinSnapshot = win.myelin.slice();
                        playbackLoader.simSnapshot = win.lastSim;
                        win.showPlayback = true;
                        win.statusLine = win.lastSim.ok
                                ? "Playback: pulse races toward the soma."
                                : "Playback: watch where the cascade stalls or bleeds out.";
                    }
                }

                Button {
                    text: "Reset"
                    onClicked: win.resetLevel()
                }

                Label {
                    text: "Click a segment to toggle myelin (green) ↔ exposed node (copper). Foot and brain stay fixed."
                    color: "#7a8699"
                    font.pixelSize: 11
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }

    Loader {
        id: playbackLoader
        anchors.fill: parent
        active: win.showPlayback
        // qrc:/ breaks in Web Dojo (HTTP); Qt.resolvedUrl works for qrc and for http://…/main.qml siblings.
        source: win.showPlayback ? Qt.resolvedUrl("Playback3D.qml") : ""

        property var myelinSnapshot: []
        property var simSnapshot: ({ ok: false, steps: [] })

        onLoaded: {
            if (!item)
                return;
            item.myelin = playbackLoader.myelinSnapshot;
            item.simResult = playbackLoader.simSnapshot;
            item.playbackFinished.connect(onPlaybackFinished);
            item.startPlayback();
        }

        function onPlaybackFinished(success, cancelled) {
            var it = playbackLoader.item;
            if (it)
                it.playbackFinished.disconnect(onPlaybackFinished);
            win.showPlayback = false;
            if (cancelled) {
                win.statusLine = "Returned to editor.";
            } else if (success) {
                win.statusLine = "Success — the cortical glow received a clean volley.";
            } else {
                win.statusLine = "Failed — " + describeFail(playbackLoader.simSnapshot.failReason);
            }
            win.refreshPreview();
        }
    }
}
