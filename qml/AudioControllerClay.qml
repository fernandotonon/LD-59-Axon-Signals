import QtQuick 2.15
import Clayground.Sound

QtObject {
    id: root

    property bool musicEnabled: true
    property bool sfxEnabled: true
    property real musicVolume: 0.18
    property real sfxVolume: 1.0

    function sfxByName(name) {
        if (name === "click")
            return clickSound;
        if (name === "toggle_myelin")
            return toggleMyelinSound;
        if (name === "node_regen")
            return nodeRegenSound;
        if (name === "fail")
            return failSound;
        if (name === "success")
            return successSound;
        return null;
    }

    function resolveAudioSource(filename) {
        return Qt.resolvedUrl("../assets/audio/" + filename);
    }

    function playSfx(name) {
        if (!sfxEnabled)
            return;
        var s = sfxByName(name);
        if (!s)
            return;
        s.play();
        if (musicEnabled && !bgm.playing)
            bgm.play();
    }

    function updateMusicState() {
        if (!musicEnabled) {
            if (bgm.playing)
                bgm.pause();
            return;
        }
        if (!bgm.playing)
            bgm.play();
    }

    Sound {
        id: clickSound
        source: resolveAudioSource("click.wav")
        volume: root.sfxVolume
        onErrorOccurred: (msg) => console.log("SFX click error:", msg)
    }

    Sound {
        id: toggleMyelinSound
        source: resolveAudioSource("toggle_myelin.wav")
        volume: root.sfxVolume
        onErrorOccurred: (msg) => console.log("SFX toggle_myelin error:", msg)
    }

    Sound {
        id: nodeRegenSound
        source: resolveAudioSource("node_regen.wav")
        volume: root.sfxVolume
        onErrorOccurred: (msg) => console.log("SFX node_regen error:", msg)
    }

    Sound {
        id: failSound
        source: resolveAudioSource("fail.wav")
        volume: root.sfxVolume
        onErrorOccurred: (msg) => console.log("SFX fail error:", msg)
    }

    Sound {
        id: successSound
        source: resolveAudioSource("success.wav")
        volume: root.sfxVolume
        onErrorOccurred: (msg) => console.log("SFX success error:", msg)
    }

    Music {
        id: bgm
        source: resolveAudioSource("bgm_main.mp3")
        volume: root.musicVolume
        loop: true
        onStatusChanged: {
            if (bgm.status === 3)
                console.log("BGM error: failed to load");
        }
    }

    onMusicEnabledChanged: updateMusicState()
    Component.onCompleted: updateMusicState()
}
