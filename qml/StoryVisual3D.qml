import QtQuick
import QtQuick3D
import QtQuick3D.AssetUtils

Item {
    id: root
    property string modelSource: ""
    property real modelScale: 24
    property real modelRotX: -10
    property real modelRotY: 0
    property real modelRotZ: 0
    property real modelPosY: -18
    property real camY: 24
    property real camZ: 170
    property real spinClock: 0
    readonly property bool modelReady: modelNode.status === RuntimeLoader.Success
    readonly property string modelError: modelNode.errorString

    View3D {
        anchors.fill: parent
        renderMode: View3D.Offscreen
        environment: SceneEnvironment {
            clearColor: "#0d152b"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }
        camera: storyCam

        PerspectiveCamera {
            id: storyCam
            position: Qt.vector3d(0, root.camY, root.camZ)
            eulerRotation.x: -8
        }

        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -25
            brightness: 1.35
        }

        PointLight {
            position: Qt.vector3d(42, 38, 78)
            brightness: 120
            quadraticFade: 0.08
            color: "#82c6ff"
        }

        PointLight {
            position: Qt.vector3d(-48, -24, 52)
            brightness: 65
            quadraticFade: 0.11
            color: "#ffb775"
        }

        RuntimeLoader {
            id: modelNode
            source: root.modelSource
            y: root.modelPosY
            scale: Qt.vector3d(root.modelScale, root.modelScale, root.modelScale)
            eulerRotation.x: root.modelRotX
            eulerRotation.y: root.modelRotY + root.spinClock * 10
            eulerRotation.z: root.modelRotZ
            onStatusChanged: {
                if (status === RuntimeLoader.Error)
                    console.log("StoryVisual3D RuntimeLoader error:", errorString, "source:", source)
            }
        }
    }
}
