// signalSim.js — pure simulation for saltatory conduction along a discretized axon.
// Kept free of QML dependencies so the same logic can be unit-tested or reused by Clayground.

.pragma library

var defaultConfig = {
    maxJump: 7,
    startEnergy: 100,
    // Per-segment jump baseline (scaled by distance and myelin fraction).
    jumpCostBase: 3.2,
    // Myelin reduces effective jump cost (saltatory conduction is efficient).
    myelinEfficiency: 0.62,
    // Extra penalty when the exposed "gap" between nodes is wide (leaky membrane feel).
    exposedGapPenalty: 1.4,
    // Global leak: too many exposed internode segments taxes the system.
    exposedDensityTax: 0.35
};

function buildNodeIndices(myelin) {
    var n = myelin.length;
    var nodes = [];
    nodes.push(0);
    for (var i = 1; i < n - 1; i++) {
        if (!myelin[i])
            nodes.push(i);
    }
    nodes.push(n - 1);
    nodes.sort(function (a, b) { return a - b; });
    var out = [];
    for (var k = 0; k < nodes.length; k++) {
        if (k === 0 || nodes[k] !== nodes[k - 1])
            out.push(nodes[k]);
    }
    return out;
}

function countMyelinBetween(myelin, fromIdx, toIdx) {
    var c = 0;
    var lo = Math.min(fromIdx, toIdx) + 1;
    var hi = Math.max(fromIdx, toIdx) - 1;
    for (var i = lo; i <= hi; i++) {
        if (myelin[i])
            c++;
    }
    return c;
}

function countExposedInterior(myelin) {
    var n = myelin.length;
    var c = 0;
    for (var i = 1; i < n - 1; i++) {
        if (!myelin[i])
            c++;
    }
    return c;
}

// Returns { ok, energy, steps, failReason } where steps is an array of leg summaries.
function simulate(myelin, cfg) {
    var c = {};
    for (var key in defaultConfig) {
        c[key] = defaultConfig[key];
    }
    if (cfg) {
        for (var k in cfg) {
            if (cfg.hasOwnProperty(k))
                c[k] = cfg[k];
        }
    }

    var n = myelin.length;
    var energy = c.startEnergy;
    var nodes = buildNodeIndices(myelin);
    var steps = [];
    var failReason = "";

    if (nodes.length < 2) {
        return {
            ok: false,
            energy: energy,
            steps: steps,
            failReason: "no_path",
            nodes: nodes,
            config: c
        };
    }

    // One-time tax for "too much exposed membrane" away from optimal saltatory spacing.
    var exposedInterior = countExposedInterior(myelin);
    energy -= exposedInterior * c.exposedDensityTax;
    steps.push({
        type: "setup",
        energyAfter: energy,
        note: "membrane_leak_tax"
    });

    for (var ni = 0; ni < nodes.length - 1; ni++) {
        var a = nodes[ni];
        var b = nodes[ni + 1];
        var dist = b - a;
        var interior = Math.max(0, dist - 1);
        var myel = countMyelinBetween(myelin, a, b);
        var myelFrac = interior > 0 ? myel / interior : 1.0;
        var exposedBetween = interior - myel;

        if (dist > c.maxJump) {
            failReason = "jump_too_far";
            // Visual-only partial hop so playback still shows an attempted saltation.
            var partialTo = Math.min(n - 1, a + c.maxJump);
            var myelPartial = countMyelinBetween(myelin, a, partialTo);
            var interiorPartial = Math.max(0, partialTo - a - 1);
            var myelFracPartial = interiorPartial > 0 ? myelPartial / interiorPartial : 1.0;
            steps.push({
                type: "jump",
                from: a,
                to: partialTo,
                dist: partialTo - a,
                myelinatedBetween: myelPartial,
                myelinatedFraction: myelFracPartial,
                cost: 0,
                energyAfter: energy,
                doomed: true
            });
            steps.push({
                type: "fail",
                from: a,
                to: b,
                dist: dist,
                energyAfter: energy,
                reason: failReason
            });
            return {
                ok: false,
                energy: energy,
                steps: steps,
                failReason: failReason,
                nodes: nodes,
                config: c
            };
        }

        var cost = dist * c.jumpCostBase;
        cost *= 1.0 - c.myelinEfficiency * myelFrac;
        cost += exposedBetween * c.exposedGapPenalty * 0.25;
        energy -= cost;

        steps.push({
            type: "jump",
            from: a,
            to: b,
            dist: dist,
            myelinatedBetween: myel,
            myelinatedFraction: myelFrac,
            cost: cost,
            energyAfter: energy
        });

        if (energy <= 0) {
            failReason = "out_of_energy";
            steps.push({
                type: "fail",
                from: a,
                to: b,
                energyAfter: energy,
                reason: failReason
            });
            return {
                ok: false,
                energy: energy,
                steps: steps,
                failReason: failReason,
                nodes: nodes,
                config: c
            };
        }
    }

    var win = energy > 0 && nodes[nodes.length - 1] === n - 1;
    return {
        ok: win,
        energy: energy,
        steps: steps,
        failReason: win ? "" : "no_energy_at_end",
        nodes: nodes,
        config: c
    };
}
