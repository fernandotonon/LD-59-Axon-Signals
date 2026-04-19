// signalSim.js - saltatory-style axon conduction (jam-friendly abstraction).
//
// signalStrength: how much depolarizing "oomph" remains as the wave moves (gameplay core).
// Myelin: low passive loss per segment. Exposed / internode gap: high loss.
// Interior Ranvier gaps: must still be strong enough to fire the node; firing resets strength
// and spends ATP. Brain: no regeneration; need strength >= brainActivationThreshold.
//
// Vm readout in UI maps strength to educational mV via strengthToDisplayVm() only.
.pragma library

var defaultConfig = {
    restingPotential: -70,
    thresholdPotential: -55,
    spikePotential: 30,

    initialSignalStrength: 100,
    signalThresholdToFireNode: 35,
    regeneratedSignalStrength: 100,

    baseMyelinDecayPerUnit: 4,
    baseUnmyelinatedDecayPerUnit: 12,

    nodeATPcost: 1,
    initialATP: 8,

    signalSpeedMyelinated: 1.4,
    signalSpeedNode: 0.7,

    brainActivationThreshold: 40
};

function segmentKind(myelin, i, n) {
    if (i < 0 || i >= n)
        return "INVALID";
    if (myelin[i])
        return "MYELIN";
    return "NODE";
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

// Map strength (0..initial) to a pseudo membrane mV for the HUD (weak = closer to threshold).
function strengthToDisplayVm(strength, c) {
    var cap = c.initialSignalStrength > 0 ? c.initialSignalStrength : 100;
    var t = Math.max(0, Math.min(1, strength / cap));
    return c.restingPotential + (1 - t) * (c.thresholdPotential - c.restingPotential);
}

function buildPlaybackTimeline(steps, n, cfg) {
    var c = {};
    for (var key in defaultConfig)
        c[key] = defaultConfig[key];
    if (cfg) {
        for (var k in cfg)
            c[k] = cfg[k];
    }

    var out = [];
    if (!steps || n < 2)
        return out;

    var baseMyelinMs = 200;
    var baseNodeMs = 280;

    for (var j = 0; j < steps.length; j++) {
        var s = steps[j];
        if (s.type !== "hop")
            continue;
        var i = s.index;
        // Decay: sweep across segment i (left → right along the axon).
        // Regen: stay at the trailing edge of that segment — the decay hop already
        // ended at toF; reusing fromF = (i+0.06)/(n-1) would snap the pulse backward.
        var fromF;
        var toF;
        if (s.phase === "regen") {
            toF = (i + 0.9) / (n - 1);
            if (i === n - 1)
                toF = 1.0;
            fromF = toF;
        } else {
            fromF = (i + 0.06) / (n - 1);
            toF = (i + 0.9) / (n - 1);
            if (i === n - 1)
                toF = 1.0;
        }

        var dur;
        if (s.phase === "regen")
            dur = baseNodeMs / c.signalSpeedNode;
        else if (s.kind === "MYELIN")
            dur = baseMyelinMs / c.signalSpeedMyelinated;
        else
            dur = baseNodeMs / c.signalSpeedNode;

        out.push({
            fromFrac: fromF,
            toFrac: toF,
            durationMs: dur,
            strengthFrom: s.strength0,
            strengthTo: s.strength1,
            atpFrom: s.atpFrom,
            atpTo: s.atpTo,
            nodeFlash: !!s.nodeFlash,
            segIndex: i,
            kind: s.kind,
            phase: s.phase
        });
    }
    return out;
}

// Returns { ok, failReason, signalStrength, atp, voltage, steps, nodes, config, lowestSignalStrength }.
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

    if (n < 2) {
        return {
            ok: false,
            failReason: "no_path",
            signalStrength: 0,
            atp: c.initialATP,
            voltage: c.restingPotential,
            peakVoltage: c.restingPotential,
            steps: steps,
            nodes: nodes,
            config: c,
            lowestSignalStrength: 0
        };
    }

    var strength = c.initialSignalStrength;
    var atp = c.initialATP;
    var lowest = strength;

    for (var k = 1; k < n; k++) {
        var s0 = strength;
        var dec = myelin[k] ? c.baseMyelinDecayPerUnit : c.baseUnmyelinatedDecayPerUnit;
        var s1 = strength - dec;

        steps.push({
            type: "hop",
            phase: "decay",
            index: k,
            kind: myelin[k] ? "MYELIN" : "NODE",
            strength0: s0,
            strength1: s1,
            atpFrom: atp,
            atpTo: atp,
            nodeFlash: false
        });

        strength = s1;
        if (strength < lowest)
            lowest = strength;

        if (k === n - 1) {
            if (strength < c.brainActivationThreshold) {
                return {
                    ok: false,
                    failReason: "brain_weak",
                    signalStrength: strength,
                    atp: atp,
                    voltage: strengthToDisplayVm(strength, c),
                    peakVoltage: strengthToDisplayVm(lowest, c),
                    steps: steps,
                    nodes: nodes,
                    config: c,
                    lowestSignalStrength: lowest
                };
            }
            return {
                ok: true,
                failReason: "",
                signalStrength: strength,
                atp: atp,
                voltage: strengthToDisplayVm(strength, c),
                peakVoltage: strengthToDisplayVm(lowest, c),
                steps: steps,
                nodes: nodes,
                config: c,
                lowestSignalStrength: lowest
            };
        }

        if (!myelin[k]) {
            if (strength < c.signalThresholdToFireNode) {
                return {
                    ok: false,
                    failReason: "faded_before_node",
                    signalStrength: strength,
                    atp: atp,
                    voltage: strengthToDisplayVm(strength, c),
                    peakVoltage: strengthToDisplayVm(lowest, c),
                    steps: steps,
                    nodes: nodes,
                    config: c,
                    lowestSignalStrength: lowest
                };
            }
            if (atp < c.nodeATPcost) {
                return {
                    ok: false,
                    failReason: "atp_exhausted",
                    signalStrength: strength,
                    atp: atp,
                    voltage: strengthToDisplayVm(strength, c),
                    peakVoltage: strengthToDisplayVm(lowest, c),
                    steps: steps,
                    nodes: nodes,
                    config: c,
                    lowestSignalStrength: lowest
                };
            }

            var atpBefore = atp;
            atp -= c.nodeATPcost;
            var s2 = c.regeneratedSignalStrength;

            steps.push({
                type: "hop",
                phase: "regen",
                index: k,
                kind: "NODE",
                strength0: strength,
                strength1: s2,
                atpFrom: atpBefore,
                atpTo: atp,
                nodeFlash: true
            });

            strength = s2;
            if (strength < lowest)
                lowest = strength;
        }
    }

    return {
        ok: false,
        failReason: "no_path",
        signalStrength: strength,
        atp: atp,
        voltage: strengthToDisplayVm(strength, c),
        peakVoltage: strengthToDisplayVm(lowest, c),
        steps: steps,
        nodes: nodes,
        config: c,
        lowestSignalStrength: lowest
    };
}
