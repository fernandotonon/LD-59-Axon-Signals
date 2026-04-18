// signalSim.js — game-style axon voltage (negative mV). Not a biophysical model.
//
// Voltage convention (algebraic):
//   • More NEGATIVE Vm = stronger / “deeper” signal (used for brighter pulse read).
//   • Vm moving toward 0 = weaker (risky); Vm >= 0 = collapsed failure.
//   • Ranvier NODE steps pull Vm toward 0 (add positive delta: nodePenalty).
//   • MYELIN steps re-deepen Vm (add negative delta: myelinBoost).
//
// All tuning lives in `defaultConfig` — tweak there only.
.pragma library

var defaultConfig = {
    // --- Voltage tuning (mV, algebraic) ---
    startVoltage: -70,
    // Ranvier NODE: move Vm toward zero (less negative), e.g. −70 + 12 = −58.
    nodePenalty: 12,
    // MYELIN: move Vm more negative again, e.g. −58 + (−6) = −64.
    myelinBoost: -6,
    // LEAKY exposed (not a true Ranvier gap): partial pull toward zero (tweakable).
    leakPenalty: 7,

    failIfVoltageGte: 0,
    brainActivationThreshold: -55,

    // Legacy field kept for QML bindings that still read `energyAfter` on steps (unused in rules).
    startEnergy: 100
};

function segmentKind(myelin, i, n) {
    if (i < 0 || i >= n)
        return "INVALID";
    if (myelin[i])
        return "MYELIN";
    if (i === 0 || i === n - 1)
        return "NODE";
    if (myelin[i - 1] && myelin[i + 1])
        return "NODE";
    return "LEAKY";
}

function isRanvierNode(myelin, i, n) {
    return segmentKind(myelin, i, n) === "NODE";
}

function buildRanvierNodeIndices(myelin) {
    var n = myelin.length;
    var out = [];
    for (var i = 0; i < n; i++) {
        if (isRanvierNode(myelin, i, n))
            out.push(i);
    }
    return out;
}

// Returns { ok, voltage, peakVoltage, steps, failReason, nodes, config }.
// peakVoltage = algebraically maximum Vm (closest to 0) seen along the trace.
function simulate(myelin, cfg) {
    var c = {};
    for (var key in defaultConfig)
        c[key] = defaultConfig[key];
    if (cfg) {
        for (var k in cfg)
            c[k] = cfg[k];
    }

    var n = myelin.length;
    var steps = [];
    var nodes = buildRanvierNodeIndices(myelin);
    var energy = c.startEnergy;

    if (n < 2) {
        return {
            ok: false,
            energy: energy,
            voltage: c.startVoltage,
            peakVoltage: c.startVoltage,
            steps: steps,
            failReason: "no_path",
            nodes: nodes,
            config: c
        };
    }

    var V = c.startVoltage;
    var peakV = V;

    for (var i = 0; i < n; i++) {
        var kind = segmentKind(myelin, i, n);
        var vBefore = V;

        if (kind === "MYELIN")
            V += c.myelinBoost;
        else if (kind === "NODE")
            V += c.nodePenalty;
        else
            V += c.leakPenalty;

        if (V > peakV)
            peakV = V;

        // Every Ranvier NODE gets a pump/ion accent in playback (sequential nodes included).
        var nodeFlash = kind === "NODE";

        steps.push({
            type: "segment",
            index: i,
            kind: kind,
            vBefore: vBefore,
            vAfter: V,
            energyAfter: energy,
            nodeFlash: nodeFlash,
            regen: false
        });

        if (V >= c.failIfVoltageGte) {
            return {
                ok: false,
                energy: energy,
                voltage: V,
                peakVoltage: peakV,
                steps: steps,
                failReason: "collapsed",
                nodes: nodes,
                config: c
            };
        }
    }

    if (V > c.brainActivationThreshold) {
        return {
            ok: false,
            energy: energy,
            voltage: V,
            peakVoltage: peakV,
            steps: steps,
            failReason: "insufficient_activation",
            nodes: nodes,
            config: c
        };
    }

    return {
        ok: true,
        energy: energy,
        voltage: V,
        peakVoltage: peakV,
        steps: steps,
        failReason: "",
        nodes: nodes,
        config: c
    };
}

function buildPlaybackTimeline(steps, n) {
    var out = [];
    if (!steps || n < 2)
        return out;
    for (var j = 0; j < steps.length; j++) {
        var s = steps[j];
        if (s.type !== "segment")
            continue;
        var i = s.index;
        var fromF = (i + 0.1) / (n - 1);
        var toF = (i + 0.92) / (n - 1);
        if (i === n - 1)
            toF = 1.0;
        var dur = 210;
        if (s.kind === "MYELIN")
            dur = 240;
        else if (s.kind === "NODE")
            dur = s.nodeFlash ? 320 : 280;
        else
            dur = 220;
        out.push({
            fromFrac: fromF,
            toFrac: toF,
            durationMs: dur,
            vFrom: s.vBefore,
            vTo: s.vAfter,
            energyEnd: s.energyAfter,
            nodeFlash: s.nodeFlash,
            segIndex: i,
            kind: s.kind
        });
    }
    return out;
}

// --- Optional learning copy (keep in this file so Web Dojo loads one .js module) ---
var eduFacts = [
    {
        id: "myelin",
        title: "Myelin",
        text: "Did you know? Myelin acts as insulation, allowing signals to travel faster along neurons."
    },
    {
        id: "ranvier_node",
        title: "Node of Ranvier",
        text: "Did you know? Nodes of Ranvier are gaps where the signal is actively regenerated."
    },
    {
        id: "pump",
        title: "Ion pumps",
        text: "Did you know? Sodium-potassium pumps help restore the balance of ions after a signal passes."
    },
    {
        id: "signal",
        title: "Neural signal",
        text: "Did you know? A neural signal is actually an electrical change in voltage across the membrane."
    }
];

function eduTextFor(id) {
    for (var ei = 0; ei < eduFacts.length; ei++) {
        if (eduFacts[ei].id === id)
            return eduFacts[ei].text;
    }
    return "";
}

function eduTitleFor(id) {
    for (var ej = 0; ej < eduFacts.length; ej++) {
        if (eduFacts[ej].id === id)
            return eduFacts[ej].title;
    }
    return "Fact";
}
