---
name: time-dividend-ledger
description: Log a finished piece of AI-assisted work into Chii's Time Dividend ledger (Supabase project chiibitsu-labs) — human-equivalent time, Chii's own time, and a plain-language log. Use when Chii says "log this", "log it", "ledger", or when a work session in chat or Cowork wraps up. Also respect her keep list.
---

# Time Dividend ledger (Claude chat & Cowork)

Records one row per work session into the `chiibitsu-labs` Supabase project
(project id `wguhmblrcfcvbheusizt`) through the Supabase connector.

## 0. Keep list first

At the start of substantial work, read the keep list once:

```sql
select label, why from public.ledger_keep where kind = 'task' and active order by sort;
```

Those are Chii's to do. Never do them; prepare around them and hand them back.

## 1. Fill in the entry

- `title`: what this session produced, a few words.
- `project`: client or project name if obvious, else omit.
- `human_minutes`, `human_low`, `human_high`: how long a competent professional
  would take to produce *this same output* by hand (research, drafting, building,
  checking; not meetings or waiting). Be honest, not generous.
- `estimate_basis`: the concrete output you're counting (e.g. "2,400-word proposal,
  3 sources read, 1 pricing table").
- `you_minutes`: Chii's own time. Give your best guess from the conversation
  (each message of hers ≈ 2–5 minutes of reading and writing) and say it in one
  line so she can correct it ("I've put you at ~25 min, say if that's off").
- `ai_minutes`: rough time you spent working, if known; else omit.
- `actions`: 3–8 plain past-tense lines, each `{ "kind": ..., "line": ... }` with
  kind `did`, `drafted`, `handled`, `handed_back` or `note`.

## 2. Record it

Run with the Supabase connector's SQL tool (dollar quotes avoid escaping problems):

```sql
select public.ledger_record($j${
  "source": "claude-chat",
  "title": "...",
  "human_minutes": 180, "human_low": 120, "human_high": 240,
  "estimate_basis": "...",
  "you_minutes": 25,
  "actions": [ {"kind": "did", "line": "..."} ]
}$j$::jsonb);
```

Use `"source": "cowork"` when running in Cowork. Then tell Chii in one line what
was logged (human-equivalent vs her minutes, saved ≈ the difference).
