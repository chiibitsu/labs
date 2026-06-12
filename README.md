# ✦ Chiibitsu Labs

A small workshop of experiments, toys, and generative things — live at
**[labs.chiibitsu.com](https://labs.chiibitsu.com/)**.

Each experiment lives in its own folder and is served at its own path. The
root is a landing page that lists them.

## Experiments

| | Path | What it is |
|---|---|---|
| **[Sigil](./sigil/)** | [`labs.chiibitsu.com/sigil/`](https://labs.chiibitsu.com/sigil/) | Type a name, watch its universe grow — a generative cosmos of colour, glyph, motion, and sound, all from one word. Single file, zero dependencies. |

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
