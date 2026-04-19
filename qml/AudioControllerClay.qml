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
        source: "../assets/audio/click.wav"
        volume: root.sfxVolume
    }

    Sound {
        id: toggleMyelinSound
        source: "../assets/audio/toggle_myelin.wav"
        volume: root.sfxVolume
    }

    Sound {
        id: nodeRegenSound
        source: "../assets/audio/node_regen.wav"
        volume: root.sfxVolume
    }

    Sound {
        id: failSound
        source: "../assets/audio/fail.wav"
        volume: root.sfxVolume
    }

    Sound {
        id: successSound
        source: "../assets/audio/success.wav"
        volume: root.sfxVolume
    }

    Music {
        id: bgm
        source: "../assets/audio/bgm_main.mp3"
        volume: root.musicVolume
        loop: true
    }

    onMusicEnabledChanged: updateMusicState()
    Component.onCompleted: updateMusicState()
}
