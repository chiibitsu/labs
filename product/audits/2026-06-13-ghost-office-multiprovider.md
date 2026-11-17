# Audit record — Ghost Office provider-agnostic live preview

- **PR:** chiibitsu/labs#10
- **Scope:** `ghost-team/index.html` — optional live-preview engine gains a provider
  toggle (Claude / OpenAI / OpenRouter) plus a free-text model id. Browser-direct
  calls with the visitor's own key; no backend. Default path is a scripted demo
  with no network calls.
- **Builder:** Claude (Claude Code). **Auditor:** Codex (cross-vendor, doc 04 Tier 3).
- **Gate result:** 5 findings, 5 fixed, 0 disputed, 0 deferred. Two consecutive
  clean passes on `bd51160`.

## Findings

| # | Sev | Finding | Disposition | Commit |
|---|-----|---------|-------------|--------|
| 1 | P1 | API key survived a provider switch — clicking Wake sent the previous vendor's credential to the newly selected vendor; with *remember* on, `saveKey()` re-persisted it relabelled under the new provider, so a later auto-run from a shared `?idea=` URL could disclose it unprompted. | Fixed — switch clears key, field, and all persisted entries; same-provider clicks are a no-op. Chose clear-on-switch over per-provider storage (smaller, fails safe). | `bd6fa7b` |
| 2 | P2 | Failed `max_completion_tokens` retry threw the *first* error, reporting an already-corrected token-limit problem instead of the real cause. | Fixed — retry surfaces its own error; non-retry path keeps the original (avoids double `res.json()` on a consumed body). | `bd6fa7b` |
| 3 | P2 | OpenAI reasoning models (o-series/gpt-5) need role `developer`, not `system`. Compounded: when `system` was the rejected field the retry regex never matched, so the path silently fell back to the demo. | Fixed — reasoning ids detected up front, sent with `developer` + `max_completion_tokens`, removing a guaranteed-failing round trip. Scoped to direct OpenAI; OpenRouter normalises roles/params and uses prefixed ids. | `bd6fa7b` |
| 4 | P2 | CSS injection: `hex()` used `/^#?[0-9a-fA-F]{3,8}$\|^hsl/` — the `^hsl` alternative was unanchored, so any string *starting* with `hsl` passed verbatim into a `<style>` block. `esc()` escapes HTML, not `;` or `url(...)`. A prompt-injected response could fire attacker-controlled requests. **The downloaded `.html` has no sandbox, so the kept artifact was the worse vector** (the preview iframe already blocked scripts). | Fixed by narrowing rather than hardening: `hex()` whole-string-anchors a complete hex colour only; scripted generator emits hex via `hsl2hex()`. Dropping `hsl` cost nothing. | `7aa6343` |
| 5 | P2 | A model may return `{"toString":null,"valueOf":null}` for a string field; `String()` throws on it. Normalizers ran outside `run()`'s only `try`, so the throw rejected the click handler, `finish()` never ran, and the page stayed disabled with `running===true` until reload. | Fixed at both levels: `str()` makes validators non-throwing (one bad field degrades to `""`, rest of the response survives); `run()` now guards `runBuild()` with `try/catch/finally`, `recoverUI()` in the `finally`. | `bd51160` |

## Verification performed by the builder

Static only — no browser, and the authoring sandbox has no egress to the provider
API hosts. Each fix was reproduced before and re-tested after:

- Provider switch with a remembered key → in-memory var, input field, and all three
  `localStorage` entries empty.
- 7 CSS-injection payloads (declaration-split, `url()`, brace-break, `expression()`,
  bare `hsl()`) → all fall back to the default; valid hex forms still accepted.
- Poison-object fields in every landing/brief string → normalise without throwing.
- Simulated mid-build throw → `running=false`, form re-enabled.
- Whole script: `node --check` plus a stubbed-DOM load (no top-level runtime error).

## Outstanding — VERIFY not performed

Doc 02 §4 is unmet: no human has walked the acceptance criteria against a running
page, and the live API paths have **never been exercised against a real endpoint**.
GitHub Pages provides no per-branch preview; the "preview" for this single static
file is opening `ghost-team/index.html` in a browser.

Click-through script (these are the acceptance criteria, written retroactively —
there is no PRD for this change):

1. Scripted path: idea → Wake → build log streams, landing page renders.
2. Download `.html` opens standalone; **↗ Open page** works.
3. Plan tab has 7 sections; copy-plan yields markdown.
4. New idea resets; share link reproduces on reload.
5. **(merge-blocking)** ⚡ → Claude → key → tick remember → switch to OpenAI →
   key field empties, and stays empty after reload.
6. Live path with a real key: log names the provider; output is about the idea.
7. **(merge-blocking)** Wrong key → provider's real error in the toast, falls back
   to the scripted demo, **form usable again**.
8. Break it: mobile width, refresh mid-build, back button, 1-word and 500-word
   ideas, an idea containing `<script>` and quotes.

## HANDOFF

- **State:** #10 pushed at `bd51160`; AUDIT cleared (2 consecutive clean passes);
  left as a **draft** on purpose — draft is the honest signal for "not yet verified".
- **Next step:** owner walks the script above, especially 5 and 7. Failures come
  back as a numbered item.
- **Open questions:** none blocking. Deferred by decision: no CI gates on this repo;
  no PRD in `product/specs/`; no per-branch preview host.
- **Note:** this record lives here because the vibeOS repo was not attached to the
  session, so `ops/tasks.md` could not be updated. That remains the real record —
  mirror this handoff there.

## Process lessons

1. Self-review did not substitute for a different vendor's model. The builder ran
   its own review pass and found none of these five; two were security bugs that
   would have shipped. The cross-vendor gate earned its cost outright.
2. Two consecutive clean passes is load-bearing, not ceremony: a clean pass on
   `bd6fa7b` was immediately followed by a genuine CSS-injection finding on that
   *same commit*. One sample is not evidence.
3. Prefer narrowing an input grammar over hardening a permissive one (finding 4).
4. Fix hostile-input bugs at the root *and* add the safety net — they fail
   differently. The net alone would have discarded whole valid responses (finding 5).
