const $ = (selector) => document.querySelector(selector);

const briefs = [
  {
    type: "Artifact",
    title: "Build a museum label for an ordinary object.",
    body: "Choose something within arm’s reach and write about it as if future historians found it in a ruined studio.",
    cards: ["Name the era it belongs to", "Invent one scandal around it", "Give it a conservation warning"]
  },
  {
    type: "Field note",
    title: "Map the invisible weather of your room.",
    body: "Notice light, noise, pressure, scent, temperature, and emotional gravity. Turn the room into a tiny forecast.",
    cards: ["Draw three pressure zones", "Write a one-line forecast", "Move one object to change the climate"]
  },
  {
    type: "Prototype",
    title: "Design a tool for your future self’s worst Tuesday.",
    body: "Make a small ritual, checklist, or interface that would help you recover momentum without needing motivation.",
    cards: ["Assume low energy", "Remove one decision", "Add a graceful escape hatch"]
  },
  {
    type: "Message",
    title: "Send a postcard from a parallel timeline.",
    body: "Write as the version of you who made one brave choice earlier. Keep it kind, concrete, and a little uncanny.",
    cards: ["Start with a place", "Mention a tradeoff", "End with one instruction"]
  },
  {
    type: "Game",
    title: "Create a one-person scavenger hunt.",
    body: "Turn your environment into a sequence of clues that lead to a reward: tea, a song, a reset, or a solved annoyance.",
    cards: ["Use five clues", "Hide one clue in plain sight", "Make the final reward useful"]
  }
];

const verbs = ["compress", "translate", "invert", "illuminate", "smuggle", "rehearse", "orbit", "catalog"];
let currentBrief = "";

function pick(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function drawStars() {
  const sky = $("#constellation");
  sky.innerHTML = Array.from({ length: 34 }, () => {
    const left = Math.random() * 100;
    const top = Math.random() * 100;
    const size = Math.random() * 4 + 2;
    const delay = Math.random() * 5;
    return `<i class="star" style="left:${left}%;top:${top}%;--size:${size}px;animation-delay:-${delay}s"></i>`;
  }).join("");
}

function forge() {
  const vibe = $("#vibe-select").value;
  const time = $("#time-select").value;
  const constraint = $("#constraint-select").value;
  const brief = pick(briefs);
  const hiddenMove = `${pick(verbs)} one detail before you call it done`;

  currentBrief = `${brief.type}: ${brief.title}\n\n${brief.body}\n\nVibe: ${vibe}\nTimebox: ${time}\nConstraint: ${constraint}\nSecret move: ${hiddenMove}.`;

  $("#brief-type").textContent = brief.type;
  $("#brief-title").textContent = brief.title;
  $("#brief-body").textContent = `${brief.body} You have ${time}; make it ${vibe}; it ${constraint}.`;
  $("#cards").innerHTML = [...brief.cards, hiddenMove].map((card, index) => `
    <article class="card">
      <b>${index === 3 ? "Secret move" : `Step ${index + 1}`}</b>
      <span>${card}</span>
    </article>
  `).join("");
  drawStars();
}

async function copyBrief() {
  if (!currentBrief) forge();
  await navigator.clipboard.writeText(currentBrief);
  const toast = $("#toast");
  toast.textContent = "Brief copied. Go make the strange little thing.";
  toast.classList.add("show");
  window.setTimeout(() => toast.classList.remove("show"), 2200);
}

$("#forge-button").addEventListener("click", forge);
$("#copy-button").addEventListener("click", copyBrief);

forge();
