---
name: log-session
description: Log the finished piece of work into Chii's Time Dividend ledger — a human-equivalent time estimate and a plain-language list of what was done. Use when a task or job session wraps up (before the final summary), or when Chii says "log this", "log it", or "ledger".
---

# Log this session to the Time Dividend ledger

Timing (AI minutes, Chii's minutes) is recorded automatically by the plugin's hooks.
Your job is the part only you can judge: **what was done** and **how long it would
have taken a competent human by hand**.

## 1. Estimate the human-equivalent time

Picture a competent professional in the right role (developer, designer, writer,
analyst) doing *this same output* by hand, starting from the same brief.

- Count research, reading, drafting, building, debugging, testing and self-review.
- Don't count meetings, waiting or approval time.
- Anchor on concrete output: files and lines changed, pages written, tables
  designed, sources read, screens built. Put those numbers in `estimate_basis`.
- Give a range (`human_low`, `human_high`) and a point estimate (`human_minutes`).
  Be honest, not generous: an inflated number makes the whole ledger worthless.

## 2. Write the log lines

3–8 lines, plain words a tired person can read, one action each, past tense.
Use `kind`: `did`, `drafted` (Chii still has to approve it), `handled`, `handed_back`
(left for Chii on purpose: keep-list items go here), or `note`.

## 3. Record it

Run the command given in your session context under "Time Dividend ledger"
(`python3 ".../ledger.py" entry`) with the JSON on stdin:

```bash
python3 "<path from session context>/ledger.py" entry <<'JSON'
{
  "title": "Human First page + PR",
  "human_minutes": 420, "human_low": 300, "human_high": 600,
  "estimate_basis": "1 new 560-line interactive page, day-cycle + dial logic, OG image script, 2 browser test passes",
  "actions": [
    {"kind": "did", "line": "built the Human First page with a scroll-driven day cycle"},
    {"kind": "did", "line": "tested it on desktop and phone in a headless browser"},
    {"kind": "handed_back", "line": "left the page's final name to you"}
  ]
}
JSON
```

The command prints what it recorded. Mention it in one line in your final message
(e.g. "Logged: ~7 h human-equivalent, ~20 min of yours"). If the command isn't in
your context, the plugin's token isn't set; say so once and move on.

## Keep list

If the session context lists keep-list items, never do them. Prepare everything
around them, then hand them back with a `handed_back` log line.
