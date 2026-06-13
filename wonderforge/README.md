# Wonderforge

Wonderforge is a tiny, self-contained imagination machine. It generates compact creative briefs from a vibe, timebox, and constraint, then adds a secret move to make the task feel more alive.

## Why it is here

The prompt was open-ended, so this project aims for something delightful, inexpensive to run, and immediately useful:

- **No paid API calls** — everything runs in the browser.
- **No build system** — open `index.html` directly or serve the folder with any static server.
- **Low cognitive load** — one button produces a complete micro-mission.
- **Accessible by default** — semantic HTML, visible controls, live-region output, responsive layout, and reduced-motion support.

## Run locally

```bash
python3 -m http.server 8000 --directory wonderforge
```

Then open <http://localhost:8000>.

## Files

- `index.html` — app structure and controls.
- `styles.css` — responsive glassmorphism interface, motion, and accessibility preferences.
- `script.js` — brief generator, copy-to-clipboard behavior, and procedural constellation.
