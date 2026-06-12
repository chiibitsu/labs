# ✦ Sigil

**A generative cosmos that is uniquely yours.**

Sigil is a single, self-contained HTML file — no libraries, no build step, no
network calls — that grows an entire audiovisual universe from one piece of
text. Type a name and you get a deterministic world: its own colour palette,
its own central glyph, its own musical scale, and thousands of particles
flowing through a seeded noise field. The same word always grows the same
cosmos. A different word grows a different one. Forever.

It's part generative artwork, part ambient instrument, part toy.

> Open [`index.html`](./index.html) in any modern browser and click **enter**.

---

## Why this exists

You asked to be surprised — for something you wouldn't think to ask for. So
instead of a typical demo app, here's a tiny, complete piece of generative art
that doubles as a showcase of what can live inside **one file**:

- a **seeded PRNG** (xmur3 → mulberry32) so every universe is reproducible
- a hand-written **Perlin noise** flow field driving the particles
- a **palette engine** that derives harmonious colour schemes from the seed
- a **procedural glyph** (an n-fold symmetric mandala) at the heart of it
- a **generative audio engine** built from raw Web Audio — drones, a
  feedback-delay "reverb", and a sparse melody quantised to a seed-chosen scale
- **interaction**: drag to bend space with a gravity well, reseed, save a frame

Every one of those systems reads from the *same* seed, so the look and the
sound of your cosmos always agree with each other.

## Controls

| Key / action        | What it does                                  |
| ------------------- | --------------------------------------------- |
| **drag / touch**    | bend space — a gravity well pulls the flow    |
| `space`             | toggle the generative soundscape              |
| `R`                 | grow a brand-new random universe              |
| `N`                 | name your own universe (any word)             |
| `S`                 | save the current frame as a PNG               |
| `C`                 | clear the canvas (keep the same cosmos)       |
| `F`                 | fullscreen                                    |
| `H`                 | hide / show the controls                      |

## Make it personal

The seed lives in the URL, so universes are shareable links:

```
index.html?seed=chiibitsu
index.html?seed=your-name-here
```

Send someone their name and they'll see *their* cosmos, exactly as you did.

## Run it

It's just a file. Any of these work:

```bash
# open it directly
open index.html            # macOS
xdg-open index.html        # Linux

# or serve it (needed if your browser blocks file:// audio)
python3 -m http.server 8000   # then visit http://localhost:8000
```

If you enable **GitHub Pages** for this repo (Settings → Pages → Source:
GitHub Actions), the included workflow publishes it automatically on every push
to `main`, and your cosmos gets a public URL.

## How it fits together

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

No dependencies. ~600 lines. Entirely yours.

---

*Built as a one-file showcase. Tweak the constants near the top of
`buildUniverse()` to change the character of every cosmos at once.*
