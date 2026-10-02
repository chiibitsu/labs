# alt=human

A field guide to the world after AI came first.

The usual idea of accessibility, flipped. Every street sign, menu, job posting, law,
and passport is written for agents first, as structured data. Human-readable prose
is the `alt` text: the fallback for a slower kind of reader.

- **Default view:** the machine-native world (JSON, logs), with the human captions as `alt="…"`.
- **Human mode:** the accessibility layer. Same world, rendered in plain language. Toggle in the status bar.
- **Reverse CAPTCHA:** "I am not a human." You'll fail. That's fine.
- **humans.txt:** the inverse of robots.txt. Lists the places agents agree not to optimise.

One `index.html`, no dependencies, no build step. `og.png` is a screenshot of the page.
