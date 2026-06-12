# ✦ Sigil

**Type a name. Watch its universe grow.**

Sigil is a single, self-contained HTML file — no libraries, no build step, no
network calls — that grows an entire audiovisual universe from one piece of
text. Enter a name and you get a deterministic world all its own: a colour
palette, a glowing central glyph, a musical scale, and thousands of particles
drifting through a seeded noise field. The same word always grows the same
cosmos. A different word grows a different one. Forever.

It's part generative artwork, part ambient instrument, part toy — and every
universe is a shareable link, so anyone can find theirs and send it to a
friend.

> **[Open `index.html`](./index.html)**, type a name, and press **create**.

---

## Try it

1. Open the page — a cosmos is already shimmering behind the prompt.
2. Type any name (yours, a friend's, a word you like) and hit **create**, or
   tap **surprise me**.
3. **Drag** across the canvas to bend space with a gravity well. Turn the sound
   up.

Every name is encoded in the URL, so universes are links you can share:

```
index.html?seed=ada
index.html?seed=your-name-here
```

Open someone's link and you drop straight into *their* cosmos, exactly as they
saw it. Send people their name and watch them discover their own.

## Controls

| Key / action        | What it does                                  |
| ------------------- | --------------------------------------------- |
| **drag / touch**    | bend space — a gravity well pulls the flow    |
| `space`             | toggle the generative soundscape              |
| `R`                 | grow a brand-new random universe              |
| `N`                 | name a new universe                           |
| `S`                 | save the current frame as a PNG               |
| `C`                 | clear the canvas (keep the same cosmos)       |
| `F`                 | fullscreen                                    |
| `H`                 | hide / show the controls                      |

## What's under the hood

It looks like art, but it's a small showcase of how much can live inside a
single file. Everything below reads from the *same* text seed, so a universe's
look and its sound always agree:

- a **seeded PRNG** (xmur3 → mulberry32) so every universe is reproducible
- a hand-written **Perlin noise** flow field driving the particles
- a **palette engine** that derives a harmonious colour scheme from the seed
- a **procedural glyph** — an n-fold symmetric mandala that breathes at the centre
- a **generative audio engine** built from raw Web Audio: drones, a
  feedback-delay "reverb", and a sparse melody quantised to a seed-chosen scale
- **interaction**: a draggable gravity well, instant reseeding, and frame export

```
seed text
   │  xmur3 hash → mulberry32 PRNG (deterministic randomness)
   ├──► palette      (base hue + harmonics)
   ├──► Perlin field (seeded permutation table → flow directions)
   ├──► glyph        (symmetry, rings, wobble)
   ├──► scale + root (which notes the music may use)
   └──► particles    (positions, lifetimes, colours)

each animation frame:
   fade canvas slightly → long luminous trails
   for every particle: sample field + swirl + pointer gravity → move → draw
   redraw the breathing glyph on top
   (audio runs on its own scheduler, plucking notes from the scale)
```

## Run / host it

It's just one file. Any of these work:

```bash
# open it directly
open index.html            # macOS
xdg-open index.html        # Linux

# or serve it (recommended — some browsers block audio on file://)
python3 -m http.server 8000   # then visit http://localhost:8000
```

**Put it online for your friends:** enable GitHub Pages (Settings → Pages →
Source: *GitHub Actions*). The included workflow publishes the page on every
push to `main`, giving every cosmos a public, shareable URL.

## Nice link previews

Shared links unfurl with a custom Open Graph card (`og.png`) — a rendered
cosmos with the wordmark. That image is itself generated with zero
dependencies; regenerate it any time with:

```bash
node scripts/gen-og.js
```

The social tags in `index.html` point at the GitHub Pages URL by default; if
you host on a custom domain, update the `og:url` / `og:image` values near the
top of the file.

---

Made by **Chiibitsu Labs** — [labs@chiibitsu.com](mailto:labs@chiibitsu.com)

*No dependencies. ~600 lines. Tweak the constants near the top of
`buildUniverse()` to change the character of every cosmos at once.*
