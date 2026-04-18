// Level progression: narrative scenarios + per-path axon layouts.
// Design fields (startVoltage, nodePenalty, myelinBoost, brainActivationThreshold mV) map into
// signalSim.js numeric config (signalStrength, ATP, decay) via each level's `sim` block.
.pragma library

function _arr() {
    var a = [];
    for (var i = 0; i < arguments.length; i++)
        a.push(!!arguments[i]);
    return a;
}

// Myelin = true, Ranvier gap = false. Ends are always nodes (false).
function patternTutorial(n) {
    // Easy: short runs of myelin, nodes every ~3 segments.
    if (n === 12)
        return _arr(0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0);
    return patternBalanced(n, 3);
}

// Few interior nodes → long myelinated gaps (risky).
function patternRiskyGaps(n) {
    var a = [];
    for (var i = 0; i < n; i++) {
        if (i === 0 || i === n - 1)
            a.push(false);
        else if (i === Math.floor(n * 0.35) || i === Math.floor(n * 0.72))
            a.push(false);
        else
            a.push(true);
    }
    return a;
}

// More nodes → safer hops, higher ATP use.
function patternSafeManyNodes(n) {
    var a = [];
    for (var i = 0; i < n; i++) {
        if (i === 0 || i === n - 1)
            a.push(false);
        else
            a.push(i % 2 === 1);
    }
    return a;
}

function patternBalanced(n, every) {
    var a = [];
    for (var i = 0; i < n; i++) {
        if (i === 0 || i === n - 1)
            a.push(false);
        else
            a.push(i % every !== 0);
    }
    return a;
}

// Too many nodes: node every 2 segments (ATP drain on hard levels).
function patternTooManyNodes(n) {
    var a = [];
    for (var i = 0; i < n; i++) {
        if (i === 0 || i === n - 1)
            a.push(false);
        else
            a.push(i % 2 === 0);
    }
    return a;
}

// Long gaps: only2 interior regeneration points.
function patternLongGaps(n) {
    var a = [];
    for (var i = 0; i < n; i++) {
        if (i === 0 || i === n - 1)
            a.push(false);
        else if (i === Math.floor(n / 3) || i === Math.floor(2 * n / 3))
            a.push(false);
        else
            a.push(true);
    }
    return a;
}

var LEVELS = [
    {
        id: 1,
        title: "Ice Cream!",
        scenarioText: "You hear the ice cream truck! Send the signal to your brain before it drives away!",
        timePressureLabel: "The truck is rolling away — there is not much time…",
        successFeedback: "You got the ice cream! \uD83C\uDF66",
        failFeedback: "The truck drove away...",
        startVoltage: -70,
        nodePenalty: 10,
        myelinBoost: -6,
        brainActivationThreshold: -55,
        sim: {
            restingPotential: -70,
            thresholdPotential: -55,
            initialSignalStrength: 100,
            regeneratedSignalStrength: 100,
            signalThresholdToFireNode: 32,
            baseMyelinDecayPerUnit: 6,
            baseUnmyelinatedDecayPerUnit: 14,
            nodeATPcost: 1,
            initialATP: 10,
            brainActivationThreshold: 26,
            signalSpeedMyelinated: 1.45,
            signalSpeedNode: 0.75
        },
        paths: [
            {
                id: "tutorial",
                label: "Quick ear-to-brain route",
                hint: "Short axon — practice myelin vs nodes.",
                segmentCount: 12,
                initialATP: 12,
                defaultMyelin: patternTutorial(12)
            }
        ]
    },
    {
        id: 2,
        title: "Too Hot!",
        scenarioText: "You touched a hot pan! Send the signal fast so your brain can react!",
        timePressureLabel: "Your hand is still on the heat — react quickly!",
        successFeedback: "You pulled your hand away in time! \uD83D\uDD25",
        failFeedback: "Too slow... it burned!",
        startVoltage: -70,
        nodePenalty: 12,
        myelinBoost: -6,
        brainActivationThreshold: -55,
        sim: {
            restingPotential: -70,
            thresholdPotential: -55,
            initialSignalStrength: 100,
            regeneratedSignalStrength: 100,
            signalThresholdToFireNode: 34,
            baseMyelinDecayPerUnit: 6,
            baseUnmyelinatedDecayPerUnit: 15,
            nodeATPcost: 2,
            initialATP: 10,
            brainActivationThreshold: 30,
            signalSpeedMyelinated: 1.5,
            signalSpeedNode: 0.8
        },
        paths: [
            {
                id: "risky",
                label: "Fast shortcut (risky gaps)",
                hint: "Fewer nodes — saves ATP but long jumps may kill the signal.",
                segmentCount: 14,
                initialATP: 11,
                defaultMyelin: patternRiskyGaps(14)
            },
            {
                id: "safe",
                label: "Longer safe route",
                hint: "More nodes regenerate the signal; watch your ATP budget.",
                segmentCount: 20,
                initialATP: 14,
                defaultMyelin: patternSafeManyNodes(20)
            }
        ]
    },
    {
        id: 3,
        title: "Watch Your Step!",
        scenarioText: "Your foot is about to step on a nail! Send the signal before it's too late!",
        timePressureLabel: "One more step — choose the right nerve path!",
        successFeedback: "You avoided the nail! \uD83E\uDEB6",
        failFeedback: "Ouch! Too late...",
        startVoltage: -70,
        nodePenalty: 14,
        myelinBoost: -6,
        brainActivationThreshold: -55,
        sim: {
            restingPotential: -70,
            thresholdPotential: -55,
            initialSignalStrength: 100,
            regeneratedSignalStrength: 100,
            signalThresholdToFireNode: 35,
            baseMyelinDecayPerUnit: 6,
            baseUnmyelinatedDecayPerUnit: 16,
            nodeATPcost: 2,
            initialATP: 11,
            brainActivationThreshold: 34,
            signalSpeedMyelinated: 1.5,
            signalSpeedNode: 0.78
        },
        paths: [
            {
                id: "optimal",
                label: "Balanced path",
                hint: "Spacing and myelin are tuned for saltatory hopping.",
                segmentCount: 18,
                initialATP: 13,
                defaultMyelin: patternBalanced(18, 4)
            },
            {
                id: "drain",
                label: "Too many nodes",
                hint: "Lots of regeneration — may exhaust ATP before the brain.",
                segmentCount: 18,
                initialATP: 12,
                defaultMyelin: patternTooManyNodes(18)
            },
            {
                id: "gaps",
                label: "Long dangerous gaps",
                hint: "Myelin runs are very long between nodes.",
                segmentCount: 18,
                initialATP: 12,
                defaultMyelin: patternLongGaps(18)
            }
        ]
    },
    {
        id: 4,
        title: "Incoming!",
        scenarioText: "A baseball is flying toward you! React before it hits you!",
        timePressureLabel: "The ball is closing distance — pick a path and send the signal!",
        successFeedback: "Nice catch! \u26BE",
        failFeedback: "You got hit!",
        startVoltage: -70,
        nodePenalty: 15,
        myelinBoost: -5,
        brainActivationThreshold: -50,
        sim: {
            restingPotential: -70,
            thresholdPotential: -50,
            initialSignalStrength: 100,
            regeneratedSignalStrength: 100,
            signalThresholdToFireNode: 36,
            baseMyelinDecayPerUnit: 5,
            baseUnmyelinatedDecayPerUnit: 15,
            nodeATPcost: 3,
            initialATP: 12,
            brainActivationThreshold: 38,
            signalSpeedMyelinated: 1.55,
            signalSpeedNode: 0.82
        },
        paths: [
            {
                id: "long",
                label: "Long stable arc",
                hint: "Distance costs decay — generous nodes help.",
                segmentCount: 24,
                initialATP: 16,
                defaultMyelin: patternBalanced(24, 4)
            },
            {
                id: "short",
                label: "Short but brutal",
                hint: "Few hops, huge gaps — expert myelin edits needed.",
                segmentCount: 15,
                initialATP: 11,
                defaultMyelin: patternRiskyGaps(15)
            },
            {
                id: "mid",
                label: "Middle compromise",
                hint: "Balanced length and node spacing.",
                segmentCount: 19,
                initialATP: 14,
                defaultMyelin: patternBalanced(19, 3)
            }
        ]
    },
    {
        id: 5,
        title: "Something Smells Off...",
        scenarioText: "You smell spoiled food. Send the signal so your brain can react!",
        timePressureLabel: "Your stomach is deciding — signal the brain before you take a bite!",
        successFeedback: "You avoided eating spoiled food! \uD83E\uDD22",
        failFeedback: "Too late... that was a bad idea.",
        startVoltage: -70,
        nodePenalty: 16,
        myelinBoost: -5,
        brainActivationThreshold: -48,
        sim: {
            restingPotential: -70,
            thresholdPotential: -48,
            initialSignalStrength: 100,
            regeneratedSignalStrength: 100,
            signalThresholdToFireNode: 36,
            baseMyelinDecayPerUnit: 5,
            baseUnmyelinatedDecayPerUnit: 17,
            nodeATPcost: 3,
            initialATP: 13,
            brainActivationThreshold: 44,
            signalSpeedMyelinated: 1.6,
            signalSpeedNode: 0.85
        },
        paths: [
            {
                id: "marathon",
                label: "Very long, steady",
                hint: "Maximum distance — plan nodes carefully.",
                segmentCount: 26,
                initialATP: 17,
                defaultMyelin: patternBalanced(26, 4)
            },
            {
                id: "volatile",
                label: "Short & unstable",
                hint: "Quick path with nasty gaps.",
                segmentCount: 16,
                initialATP: 12,
                defaultMyelin: patternRiskyGaps(16)
            },
            {
                id: "tricky",
                label: "Tricky optimal",
                hint: "Looks innocent — needs tight myelin placement.",
                segmentCount: 22,
                initialATP: 14,
                defaultMyelin: patternLongGaps(22)
            }
        ]
    }
];

function levelCount() {
    return LEVELS.length;
}

function getLevel(index) {
    if (index < 0 || index >= LEVELS.length)
        return LEVELS[0];
    return LEVELS[index];
}

// Merge level sim with per-path ATP override (and optional path.simExtra).
function mergeSim(level, path) {
    var out = {};
    if (!level || !level.sim) {
        out.restingPotential = -70;
        out.thresholdPotential = -55;
        return out;
    }
    for (var k in level.sim)
        out[k] = level.sim[k];
    if (path) {
        if (path.initialATP !== undefined)
            out.initialATP = path.initialATP;
        if (path.simExtra) {
            for (var p in path.simExtra)
                out[p] = path.simExtra[p];
        }
    }
    return out;
}
