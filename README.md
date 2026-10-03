# ✦ Chiibitsu Labs

A small workshop of experiments, toys, and generative things — live at
**[labs.chiibitsu.com](https://labs.chiibitsu.com/)**.

Each experiment lives in its own folder and is served at its own path. The
root is a landing page that lists them.

## Experiments

| | Path | What it is |
|---|---|---|
| **[Sigil](./sigil/)** | [`labs.chiibitsu.com/sigil/`](https://labs.chiibitsu.com/sigil/) | Type a name, watch its universe grow — a generative cosmos of colour, glyph, motion, and sound, all from one word. Single file, zero dependencies. |
| **[Ghost Office](./ghost-team/)** | [`labs.chiibitsu.com/ghost-team/`](https://labs.chiibitsu.com/ghost-team/) | Pitch a company in one sentence and watch a team of Claude Code sub-agents ship the founding plan, live. A playable demo of a sub-agent team for solo founders — then [run it for real](./ghost-team/). |
| **[Wonderforge](./wonderforge/)** | [`labs.chiibitsu.com/wonderforge/`](https://labs.chiibitsu.com/wonderforge/) | A pocket-sized imagination machine: pick a vibe, a timebox, and a constraint, get a tiny creative mission with a secret move. Runs in the browser, no API calls, no build. |
| **[Guest Mode](./ai-first/)** | [`labs.chiibitsu.com/ai-first/`](https://labs.chiibitsu.com/ai-first/) | A city where AI came first and humans are accommodated guests. One switch flips the same town between courtesy time and machine-native time. Single file, zero dependencies. |
| **[The Human Lane](./human-lane/)** | [`labs.chiibitsu.com/human-lane/`](https://labs.chiibitsu.com/human-lane/) | 2041: the world runs AI-first and people get the accessibility layer. Fail a reverse CAPTCHA, then tour a world where speed is free and human wanting is the scarce thing. Single file, zero dependencies. |
| **[alt=human](./alt-human/)** | [`labs.chiibitsu.com/alt-human/`](https://labs.chiibitsu.com/alt-human/) | A field guide to the world after AI came first. Everything is written for agents; humans read the accessibility layer. Single file, zero dependencies. |
| **[Mine.](./mine/)** | [`labs.chiibitsu.com/mine/`](https://labs.chiibitsu.com/mine/) | Your AI can help with almost everything. Write down what it can't have: a card for you, a `mine.txt` for agents, and instructions to paste into your AI. Private, single file, zero dependencies. |
| **[manners.txt](./manners/)** | [`labs.chiibitsu.com/manners/`](https://labs.chiibitsu.com/manners/) | Draft v0.1 of house rules for every AI, written by the commons. robots.txt told machines where not to go; manners.txt tells them how to behave. [Propose a rule](https://github.com/chiibitsu/labs/issues/new?template=manners-rule.md). |

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
