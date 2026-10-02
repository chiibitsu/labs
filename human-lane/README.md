# The Human Lane

A visit to 2041, where the world is built for AI first and people get the
accessibility layer.

1. **The gate.** An unCAPTCHA asks you to prove you're *not* human: add 48
   numbers in 400 ms, spot SHA-256 prefixes in 250 ms, read 412,880 words of
   terms in 600 ms. You fail. The verdict lists your real signals (how long you
   hesitated, how much your cursor drifted).
2. **The lane.** The accommodation layer, kept open by law: agent vs. human
   counters, a feed of small human decisions, six everyday scenes in *native*
   vs. *human-alt*, the most-wanted human jobs, a seven-article charter, and
   network weather.
3. **View native.** Swap to the same page as agents read it: a firehose of
   JSON.
4. **One unoptimized choice.** Pick between two things for no reason; the agent
   network lights up around it.

The point: when AI comes first, speed is free and answers are everywhere.
What stays scarce is a person wanting something.

## Run locally

```bash
python3 -m http.server 8000 --directory human-lane
```

Open <http://localhost:8000>. Add `?lane` to skip the gate.

## Files

- `index.html` — the whole thing. No build, no dependencies.
- `og.png` — social card, made by `scripts/gen-og.js` (Playwright screenshot of the hero).
