// Lightweight 3D playback: real 3D coordinates + weak-perspective projection to 2D Canvas.
// Avoids Qt3D / Quick3D so the project runs on Qt5/Qt6 installs with only Qt Quick.

import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    anchors.fill: parent

    property var myelin: []
    property var simResult: ({ ok: false, steps: [], nodes: [] })
    property bool running: false

    // success: simulation outcome; cancelled: user left playback early.
    signal playbackFinished(bool success, bool cancelled)

    readonly property color axonCore: "#4fdfff"
    readonly property color myelinSheath: "#1f6b3a"
    readonly property color nodeGlow: "#ff7a18"
    readonly property color brainGlow: "#c86bff"

    function axonPointAtIndex(i, n) {
        var t = n <= 1 ? 0 : i / (n - 1);
        var z = 6 + t * 42;
        var x = Math.sin(t * 3.14159 * 1.35) * 5.5;
        var y = Math.cos(t * 3.14159 * 0.9) * 2.8;
        return { x: x, y: y, z: z };
    }

    function project(p, cam) {
        var dz = p.z - cam.z;
        if (dz < 0.4)
            dz = 0.4;
        var s = cam.focal / dz;
        return {
            x: cam.cx + p.x * s,
            y: cam.cy - p.y * s,
            scale: Math.max(0.15, s)
        };
    }

    function lerp(a, b, u) {
        return a + (b - a) * u;
    }

    function pointAlongAxon(frac, n) {
        var idx = frac * (n - 1);
        var i0 = Math.floor(idx);
        var i1 = Math.min(n - 1, i0 + 1);
        var u = idx - i0;
        var p0 = axonPointAtIndex(i0, n);
        var p1 = axonPointAtIndex(i1, n);
        return {
            x: lerp(p0.x, p1.x, u),
            y: lerp(p0.y, p1.y, u),
            z: lerp(p0.z, p1.z, u)
        };
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#050814" }
            GradientStop { position: 1.0; color: "#0a1024" }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        property var cam: ({
            x: 0, y: 0.8, z: -2.5,
            cx: width * 0.5, cy: height * 0.42, focal: 420
        })

        property real pulseFrac: 0
        property real flicker: 0
        property real failBlend: 0
        property bool successPulse: false

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "#00000000";
            ctx.fillRect(0, 0, width, height);

            var n = root.myelin.length;
            if (n < 2)
                return;

            // --- Sort segment indices back-to-front for painter's algorithm ---
            var order = [];
            for (var si = 0; si < n; si++)
                order.push(si);
            order.sort(function (a, b) {
                var pa = axonPointAtIndex(a, n);
                var pb = axonPointAtIndex(b, n);
                return pb.z - pa.z;
            });

            // --- Draw each discrete segment as a short 3D capsule (two projected radii) ---
            for (var t = 0; t < order.length; t++) {
                var i = order[t];
                var pA = axonPointAtIndex(i, n);
                var pB = axonPointAtIndex(Math.min(n - 1, i + 1), n);
                var mid = {
                    x: (pA.x + pB.x) * 0.5,
                    y: (pA.y + pB.y) * 0.5,
                    z: (pA.z + pB.z) * 0.5
                };
                var pr = project(mid, canvas.cam);
                var isMyelin = root.myelin[i];
                var baseR = isMyelin ? 9.5 * pr.scale : 5.2 * pr.scale;
                var col = isMyelin ? root.myelinSheath : "#14332a";
                var alpha = isMyelin ? 0.92 : 0.55;

                var grad = ctx.createRadialGradient(pr.x, pr.y, baseR * 0.15, pr.x, pr.y, baseR);
                grad.addColorStop(0, isMyelin ? "rgba(79,223,255," + (alpha * 0.95) + ")"
                                             : "rgba(79,223,255," + (alpha * 0.75) + ")");
                grad.addColorStop(0.45, isMyelin ? "rgba(31,107,58," + alpha + ")"
                                                 : "rgba(20,51,42," + alpha + ")");
                grad.addColorStop(1, "rgba(10,20,30,0)");
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.arc(pr.x, pr.y, baseR, 0, Math.PI * 2);
                ctx.fill();

                if (!isMyelin) {
                    ctx.strokeStyle = "rgba(255,122,24,0.55)";
                    ctx.lineWidth = Math.max(1, 2.2 * pr.scale);
                    ctx.beginPath();
                    ctx.arc(pr.x, pr.y, baseR * 0.55, 0, Math.PI * 2);
                    ctx.stroke();
                }
            }

            // --- Traveling pulse ---
            var pf = canvas.pulseFrac;
            var pulsePos = pointAlongAxon(pf, n);
            var pp = project(pulsePos, canvas.cam);
            var pulseR = (10 + 6 * Math.sin(pf * 40)) * pp.scale;

            ctx.fillStyle = "rgba(79,223,255," + (0.35 + 0.25 * (1 - canvas.failBlend)) + ")";
            ctx.beginPath();
            ctx.arc(pp.x, pp.y, pulseR * 1.35, 0, Math.PI * 2);
            ctx.fill();

            var flick = 1 - 0.35 * canvas.flicker;
            ctx.fillStyle = "rgba(255,242,217," + (0.85 * flick * (1 - 0.5 * canvas.failBlend)) + ")";
            ctx.beginPath();
            ctx.arc(pp.x, pp.y, pulseR * 0.45, 0, Math.PI * 2);
            ctx.fill();

            // --- Brain endpoint ---
            var endP = axonPointAtIndex(n - 1, n);
            var ep = project(endP, canvas.cam);
            var brainPulse = canvas.successPulse ? 1.35 : 1.0;
            var g2 = ctx.createRadialGradient(ep.x, ep.y, 3, ep.x, ep.y, 46 * ep.scale * brainPulse);
            g2.addColorStop(0, "rgba(200,107,255,0.95)");
            g2.addColorStop(0.4, "rgba(200,107,255,0.35)");
            g2.addColorStop(1, "rgba(200,107,255,0)");
            ctx.fillStyle = g2;
            ctx.beginPath();
            ctx.arc(ep.x, ep.y, 46 * ep.scale * brainPulse, 0, Math.PI * 2);
            ctx.fill();

            // --- Vignette ---
            var vg = ctx.createRadialGradient(canvas.cam.cx, canvas.cam.cy, canvas.height * 0.25,
                canvas.cam.cx, canvas.cam.cy, canvas.height * 0.72);
            vg.addColorStop(0, "rgba(0,0,0,0)");
            vg.addColorStop(1, "rgba(0,0,0,0.55)");
            ctx.fillStyle = vg;
            ctx.fillRect(0, 0, width, height);
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    Timer {
        id: tick
        interval: 16
        repeat: true
        running: root.running
        property var timeline: []
        property int legIndex: 0
        property real legU: 0
        property real globalTime: 0

        onTriggered: {
            globalTime += interval;
            if (timeline.length === 0) {
                root.running = false;
                return;
            }

            var leg = timeline[legIndex];
            var stepScale = (!root.simResult.ok) ? (1.0 - 0.35 * canvas.failBlend) : 1.0;
            legU += (interval / leg.durationMs) * stepScale;
            if (legU >= 1.0) {
                legU = 0;
                legIndex++;
                if (legIndex >= timeline.length) {
                    canvas.pulseFrac = 1.0;
                    canvas.successPulse = root.simResult.ok;
                    canvas.requestPaint();
                    root.running = false;
                    root.playbackFinished(root.simResult.ok, false);
                    return;
                }
                leg = timeline[legIndex];
            }

            var n = root.myelin.length;
            var smooth = legU * legU * (3 - 2 * legU);
            canvas.pulseFrac = root.lerp(leg.fromFrac, leg.toFrac, smooth);

            var pulsePos = pointAlongAxon(canvas.pulseFrac, n);
            var targetCx = canvas.width * 0.5 + pulsePos.x * 28;
            var targetCy = canvas.height * 0.42 - pulsePos.y * 28;
            canvas.cam.cx += (targetCx - canvas.cam.cx) * 0.14;
            canvas.cam.cy += (targetCy - canvas.cam.cy) * 0.14;

            if (!root.simResult.ok && legIndex >= timeline.length - 1) {
                canvas.failBlend = Math.min(1, canvas.failBlend + 0.04);
                canvas.flicker = Math.random();
            } else if (!root.simResult.ok) {
                canvas.flicker = 0.15 * Math.random();
            } else {
                canvas.flicker = 0.04 * Math.random();
            }

            canvas.requestPaint();
        }
    }

    function buildTimeline() {
        var n = root.myelin.length;
        var out = [];
        var steps = root.simResult.steps || [];
        for (var i = 0; i < steps.length; i++) {
            var s = steps[i];
            if (s.type !== "jump")
                continue;
            var toFrac = (n <= 1) ? 0 : s.to / (n - 1);
            var fromF = (n <= 1) ? 0 : s.from / (n - 1);
            var dist = s.dist || 1;
            var myel = s.myelinatedFraction != null ? s.myelinatedFraction : 0.5;
            var cost = s.cost != null ? s.cost : 1;
            // Myelinated legs feel snappier; costly legs slow down (energy drain feel).
            var durationMs = 320 + dist * 95 + cost * 26 - myel * 220;
            if (s.doomed)
                durationMs *= 1.55;
            durationMs = Math.max(220, Math.min(2000, durationMs));
            out.push({
                fromFrac: fromF,
                toFrac: toFrac,
                durationMs: durationMs
            });
        }
        return out;
    }

    function startPlayback() {
        canvas.cam.cx = canvas.width * 0.5;
        canvas.cam.cy = canvas.height * 0.42;
        canvas.pulseFrac = 0;
        canvas.failBlend = 0;
        canvas.flicker = 0;
        canvas.successPulse = false;
        tick.timeline = buildTimeline();
        tick.legIndex = 0;
        tick.legU = 0;
        tick.globalTime = 0;
        if (tick.timeline.length === 0) {
            root.playbackFinished(root.simResult.ok, false);
            return;
        }
        root.running = true;
        canvas.requestPaint();
    }

    Label {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        text: root.simResult.ok ? "Propagation: stable" : "Propagation: critical"
        color: "#dfefff"
        font.pixelSize: 15
        style: Text.Outline
        styleColor: "#000000"
    }

    Button {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 18
        text: "Back to editor"
        enabled: !root.running
        onClicked: root.playbackFinished(false, true)
    }
}
