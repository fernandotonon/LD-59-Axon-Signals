// eduFacts.js — short "Did you know?" strings for optional learning markers.
// Extend `facts` with { id, title, text } entries; keep text to 1–2 sentences.
.pragma library

var facts = [
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

function textFor(id) {
    for (var i = 0; i < facts.length; i++) {
        if (facts[i].id === id)
            return facts[i].text;
    }
    return "";
}

function titleFor(id) {
    for (var j = 0; j < facts.length; j++) {
        if (facts[j].id === id)
            return facts[j].title;
    }
    return "Fact";
}
