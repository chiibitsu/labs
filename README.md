# ✦ Chiibitsu Labs

A small workshop of experiments, toys, and generative things — live at
**[labs.chiibitsu.com](https://labs.chiibitsu.com/)**.

Each experiment lives in its own folder and is served at its own path. The
root is a landing page that lists them.

## Experiments

| | Path | What it is |
|---|---|---|
| **[What We Kept](./2045/)** | [`labs.chiibitsu.com/2045/`](https://labs.chiibitsu.com/2045/) | One day in 2045 (Friday 28 July). Name your agent and child, pick your work (principal, nurse, teacher). AI handles almost everything; every choice is one tap to delegate or doing it yourself with your hands. Varies on every replay. Ends with a receipt of what you kept and the 2026 signals behind each scene. Single file, zero dependencies. |
| **[Sigil](./sigil/)** | [`labs.chiibitsu.com/sigil/`](https://labs.chiibitsu.com/sigil/) | Type a name, watch its universe grow — a generative cosmos of colour, glyph, motion, and sound, all from one word. Single file, zero dependencies. |
| **[Ghost Office](./ghost-team/)** | [`labs.chiibitsu.com/ghost-team/`](https://labs.chiibitsu.com/ghost-team/) | Pitch a company in one sentence and watch a team of Claude Code sub-agents ship the founding plan, live. A playable demo of a sub-agent team for solo founders — then [run it for real](./ghost-team/). |
| **[Wonderforge](./wonderforge/)** | [`labs.chiibitsu.com/wonderforge/`](https://labs.chiibitsu.com/wonderforge/) | A pocket-sized imagination machine: pick a vibe, a timebox, and a constraint, get a tiny creative mission with a secret move. Runs in the browser, no API calls, no build. |
| **[Guest Mode](./ai-first/)** | [`labs.chiibitsu.com/ai-first/`](https://labs.chiibitsu.com/ai-first/) | A city where AI came first and humans are accommodated guests. One switch flips the same town between courtesy time and machine-native time. Single file, zero dependencies. |
| **[Say It Well](./receipt/)** | [`labs.chiibitsu.com/receipt/`](https://labs.chiibitsu.com/receipt/) | Machines say “Rejected.” You can do better. Answer a few questions about a hard moment (saying no, asking, owning a mistake) and get a message that is clear, kind and yours. 14 moments, no AI, nothing leaves the page. Also: a [message checker](./receipt/check/) and a [draft standard](./receipt/standard/) for institutions. |
| **[The Human Lane](./human-lane/)** | [`labs.chiibitsu.com/human-lane/`](https://labs.chiibitsu.com/human-lane/) | 2041: the world runs AI-first and people get the accessibility layer. Fail a reverse CAPTCHA, then tour a world where speed is free and human wanting is the scarce thing. Single file, zero dependencies. |
| **[alt=human](./alt-human/)** | [`labs.chiibitsu.com/alt-human/`](https://labs.chiibitsu.com/alt-human/) | A field guide to the world after AI came first. Everything is written for agents; humans read the accessibility layer. Single file, zero dependencies. |
| **[Friday, 2045](./friday-2045/)** | [`labs.chiibitsu.com/friday-2045/`](https://labs.chiibitsu.com/friday-2045/) | A ten-minute game. Live one ordinary day in 2045 (28 July) when AI is native to the world: a voice that lives with you, a queue you sign, an outage that shows what you still know how to do. Every beat links to the 2025–26 signal behind it. Mobile-first, sound, haptics, single file, zero dependencies. |

## Layout

```
labs/
├── index.html        landing page (the hub)
├── CNAME             custom domain: labs.chiibitsu.com
├── .github/workflows/pages.yml   deploys the whole repo to GitHub Pages
└── sigil/            an experiment
    ├── index.html
    ├── og.png
    ├── README.md
    └── scripts/
```

## Adding a new experiment

1. Create a folder, e.g. `my-thing/`, with its own `index.html`.
2. Add a card for it in the root `index.html` (copy the Sigil card, point the
   link at `my-thing/`).
3. Commit to `main` — the Pages workflow publishes everything automatically,
   and it's live at `labs.chiibitsu.com/my-thing/`.

No build step, no per-experiment DNS — one domain, many sub-paths.

## Hosting

Served by GitHub Pages (Settings → Pages → Source: *GitHub Actions*). The
[`pages.yml`](./.github/workflows/pages.yml) workflow uploads the repo root on
every push to `main`. The `CNAME` file binds the `labs.chiibitsu.com` domain.

---

Made by **Chiibitsu Labs** — [chiibitsu.com](https://chiibitsu.com)
