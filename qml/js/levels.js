// Level progression: narrative scenarios + per-path axon layouts.
// Design fields (startVoltage, nodePenalty, myelinBoost, brainActivationThreshold mV) map into
// signalSim.js numeric config via each level's `sim` block.
// Every path starts fully myelinated; players strip myelin to place Ranvier nodes.
.pragma library

// Myelin = true, Ranvier gap = false. Endpoints stay nodes (false); interior starts all myelin.
function fullMyelin(n) {
    var a = [];
    for (var i = 0; i < n; i++)
        a.push(i !== 0 && i !== n - 1);
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
        startOrgan: "Ear",
        startMarker: "E",
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
                hint: "Short hop — tight timing; sheath starts intact end to end.",
                segmentCount: 12,
                initialATP: 12,
                defaultMyelin: fullMyelin(12)
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
        startOrgan: "Hand",
        startMarker: "H",
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
                hint: "Fewer segments; long exposed runs bleed strength quickly.",
                segmentCount: 14,
                initialATP: 11,
                defaultMyelin: fullMyelin(14)
            },
            {
                id: "safe",
                label: "Longer safe route",
                hint: "More segments and ATP — each regen costs energy.",
                segmentCount: 20,
                initialATP: 14,
                defaultMyelin: fullMyelin(20)
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
        startOrgan: "Eye",
        startMarker: "I",
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
                hint: "Balanced length and starting ATP.",
                segmentCount: 18,
                initialATP: 13,
                defaultMyelin: fullMyelin(18)
            },
            {
                id: "drain",
                label: "Long path, tight ATP",
                hint: "Same length as balanced; slightly leaner ATP pool.",
                segmentCount: 18,
                initialATP: 12,
                defaultMyelin: fullMyelin(18)
            },
            {
                id: "gaps",
                label: "Wide axon",
                hint: "Same 18 segments and ATP as drain — alternate run with identical numbers.",
                segmentCount: 18,
                initialATP: 12,
                defaultMyelin: fullMyelin(18)
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
        startOrgan: "Hand",
        startMarker: "H",
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
                hint: "Long axon; more room to tune, more places to lose the wave.",
                segmentCount: 24,
                initialATP: 16,
                defaultMyelin: fullMyelin(24)
            },
            {
                id: "short",
                label: "Short but brutal",
                hint: "Short axon; each exposed step hurts more.",
                segmentCount: 15,
                initialATP: 11,
                defaultMyelin: fullMyelin(15)
            },
            {
                id: "mid",
                label: "Middle compromise",
                hint: "Middle length and ATP — jack of all trades.",
                segmentCount: 19,
                initialATP: 14,
                defaultMyelin: fullMyelin(19)
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
        startOrgan: "Nose",
        startMarker: "N",
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
                hint: "Maximum distance; small mistakes echo down the whole axon.",
                segmentCount: 26,
                initialATP: 17,
                defaultMyelin: fullMyelin(26)
            },
            {
                id: "volatile",
                label: "Short & unstable",
                hint: "Fewer segments; brain wants a stronger arrival.",
                segmentCount: 16,
                initialATP: 12,
                defaultMyelin: fullMyelin(16)
            },
            {
                id: "tricky",
                label: "Tricky optimal",
                hint: "Mid length; sharp thresholds — little margin for sloppy hops.",
                segmentCount: 22,
                initialATP: 14,
                defaultMyelin: fullMyelin(22)
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
