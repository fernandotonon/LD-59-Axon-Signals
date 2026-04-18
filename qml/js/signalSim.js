// signalSim.js — simplified membrane potential + ATP (game-readable, not biophysical).
.pragma library

var defaultConfig = {
    regenVmV: -55,
    failVmV: -70,
    startVmV: -55,
    startEnergy: 100,
    decayMyelinMv: 3.0,
    decayLeakyMv: 9.0,
    nodeAtpCost: 14
};

// MYELIN = internode sheath; NODE = foot, brain, or true gap between myelin; LEAKY = exposed but not a Ranvier gap.
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

// Kept for tooling / QML; lists indices where pumps may appear (all NODE kinds).
function buildRanvierNodeIndices(myelin) {
    var n = myelin.length;
    var out = [];
    for (var i = 0; i < n; i++) {
        if (isRanvierNode(myelin, i, n))
            out.push(i);
    }
    return out;
}

// Returns { ok, energy, voltage, minVoltage, steps, failReason, nodes, config }.
function simulate(myelin, cfg) {
    var c = {};
    for (var key in defaultConfig)
        c[key] = defaultConfig[key];
    if (cfg) {
        for (var k in cfg) {
            if (cfg.hasOwnProperty(k))
                c[k] = cfg[k];
        }
    }

    var n = myelin.length;
    var steps = [];
    var failReason = "";
    var nodes = buildRanvierNodeIndices(myelin);

    if (n < 2) {
        return {
            ok: false,
            energy: c.startEnergy,
            voltage: c.startVmV,
            minVoltage: c.startVmV,
            steps: steps,
            failReason: "no_path",
            nodes: nodes,
            config: c
        };
    }

    var V = c.startVmV;
    var energy = c.startEnergy;
    var minV = V;

    for (var i = 0; i < n; i++) {
        var kind = segmentKind(myelin, i, n);
        var vBefore = V;
        var nodeFlash = false;
        var regen = false;

        if (kind === "MYELIN") {
            V -= c.decayMyelinMv;
        } else if (kind === "NODE") {
            if (i === 0) {
                V = c.regenVmV;
                regen = true;
            } else if (i === n - 1) {
                V = c.regenVmV;
                regen = true;
                nodeFlash = true;
            } else {
                energy -= c.nodeAtpCost;
                V = c.regenVmV;
                regen = true;
                nodeFlash = true;
            }
        } else {
            V -= c.decayLeakyMv;
        }

        if (V < minV)
            minV = V;

        steps.push({
            type: "segment",
            index: i,
            kind: kind,
            vBefore: vBefore,
            vAfter: V,
            energyAfter: energy,
            nodeFlash: nodeFlash,
            regen: regen
        });

        if (V < c.failVmV) {
            failReason = "under_voltage";
            return {
                ok: false,
                energy: energy,
                voltage: V,
                minVoltage: minV,
                steps: steps,
                failReason: failReason,
                nodes: nodes,
                config: c
            };
        }
        if (energy <= 0 && i < n - 1) {
            failReason = "out_of_energy";
            return {
                ok: false,
                energy: energy,
                voltage: V,
                minVoltage: minV,
                steps: steps,
                failReason: failReason,
                nodes: nodes,
                config: c
            };
        }
    }

    var win = V > c.failVmV && energy > 0;
    return {
        ok: win,
        energy: energy,
        voltage: V,
        minVoltage: minV,
        steps: steps,
        failReason: win ? "" : (energy <= 0 ? "out_of_energy" : "under_voltage"),
        nodes: nodes,
        config: c
    };
}

// Playback legs: pulse sweeps each segment; carries vFrom/vTo for glow interpolation.
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
        var dur = 185;
        if (s.kind === "NODE" && s.nodeFlash)
            dur = 360;
        else if (s.kind === "NODE")
            dur = 275;
        else if (s.kind === "LEAKY")
            dur = 235;
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
