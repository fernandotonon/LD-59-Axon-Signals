import QtQuick
import QtMultimedia

QtObject {
    id: root

    property bool musicEnabled: true
    property bool sfxEnabled: true
    property real musicVolume: 0.18
    property real sfxVolume: 1.0

    function sfxFileByName(name) {
        if (name === "click")
            return "click.wav";
        if (name === "toggle_myelin")
            return "toggle_myelin.wav";
        if (name === "node_regen")
            return "node_regen.wav";
        if (name === "fail")
            return "fail.wav";
        if (name === "success")
            return "success.wav";
        return "";
    }

    function resolveAudioSource(filename) {
        var base = "" + Qt.resolvedUrl("main.qml");
        if (base.indexOf("qrc:/") === 0)
            return "qrc:/assets/audio/" + filename;
        return "../assets/audio/" + filename;
    }

    function effectByName(name) {
        if (name === "click")
            return clickSfx;
        if (name === "toggle_myelin")
            return toggleMyelinSfx;
        if (name === "node_regen")
            return nodeRegenSfx;
        if (name === "fail")
            return failSfx;
        if (name === "success")
            return successSfx;
        return null;
    }

    function playSfx(name) {
        if (!sfxEnabled)
            return;
        var effect = effectByName(name);
        if (effect && effect.status === SoundEffect.Ready) {
            effect.stop();
            effect.play();
        } else {
            var f = sfxFileByName(name);
            if (f === "")
                return;
            sfxPlayer.stop();
            sfxPlayer.source = resolveAudioSource(f);
            sfxPlayer.play();
        }

        // In browsers with autoplay restrictions, user-triggered SFX is a good
        // moment to attempt music start/resume.
        if (musicEnabled && bgm.playbackState !== MediaPlayer.PlayingState)
            bgm.play();
    }

    function updateMusicState() {
        if (!musicEnabled) {
            if (bgm.playbackState === MediaPlayer.PlayingState)
                bgm.pause();
            return;
        }
        if (bgm.playbackState !== MediaPlayer.PlayingState)
            bgm.play();
    }

    AudioOutput {
        id: bgmOut
        volume: root.musicVolume
    }

    AudioOutput {
        id: sfxOut
        volume: root.sfxVolume
    }

    MediaPlayer {
        id: bgm
        source: resolveAudioSource("bgm_main.mp3")
        audioOutput: bgmOut
        loops: MediaPlayer.Infinite
        onErrorOccurred: console.log("BGM error:", errorString)
    }

    MediaPlayer {
        id: sfxPlayer
        audioOutput: sfxOut
        onErrorOccurred: console.log("SFX fallback player error:", errorString)
    }

    SoundEffect {
        id: clickSfx
        source: resolveAudioSource("click.wav")
        volume: root.sfxVolume
    }

    SoundEffect {
        id: toggleMyelinSfx
        source: resolveAudioSource("toggle_myelin.wav")
        volume: root.sfxVolume
    }

    SoundEffect {
        id: nodeRegenSfx
        source: resolveAudioSource("node_regen.wav")
        volume: root.sfxVolume
    }

    SoundEffect {
        id: failSfx
        source: resolveAudioSource("fail.wav")
        volume: root.sfxVolume
    }

    SoundEffect {
        id: successSfx
        source: resolveAudioSource("success.wav")
        volume: root.sfxVolume
    }

    onMusicEnabledChanged: updateMusicState()
    Component.onCompleted: updateMusicState()
}
