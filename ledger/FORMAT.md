# The ledger line, and how to plug in another tool

## 1. The line format

One JSON object per session (or per call). Send the same `source` + `external_id`
again and it updates that line instead of adding a new one. **Leave a field out when
the tool did not report it. Never send 0 or a guess for "unknown".**

| You want | Field | Notes |
|---|---|---|
| **when** | `started_at`, `ended_at` | ISO 8601, with timezone. `started_at` defaults to now. |
| **tool** | `source` | Required. Short name: `claude-code`, `codex`, `local-model`. |
| **model** | `model` | One model name. The client turns it into `model_usage`. For several models, send `model_usage` yourself: `{"name": {"inputTokens": n, "cacheCreationInputTokens": n, "cacheReadInputTokens": n, "outputTokens": n}}`. |
| **project** | `project` | By rule, not by judgment: `$LEDGER_PROJECT` if set, else the git repo name from `origin`, else the folder name. Left out = the client applies that rule. |
| **tokens** | `tokens_input`, `tokens_cache_read`, `tokens_output` | `tokens_input` includes tokens written to cache. Whole numbers ≥ 0. |
| **AI minutes** | `ai_minutes` | Minutes the AI was working. Number ≥ 0. |
| **cost** | `cost_usd` + `cost_basis` | Both or neither. `cost_basis`: `reported` (the tool said so), `estimate` (we priced the tokens from list prices), `partial` (only some models could be priced), `manual` (typed by hand). |
| (optional) | `external_id`, `title`, `you_minutes`, `human_minutes`, … | Same as today; see `plugin/scripts/ledger.py`. |

**Cost on a subscription is an API-price equivalent, not money spent.**
The ledger page and the CSV should say so wherever cost is shown.

The only new field is `model` (a client-side convenience). The database stores the
model inside the existing `model_usage` column; no database change.

Send it with:

```bash
echo '{"source":"my-tool","model":"x","tokens_output":120,"ai_minutes":1.5}' | python3 ledger/plugin/scripts/ledger.py emit
```

`emit` refuses bad lines and says why (nothing is sent). With no `LEDGER_TOKEN` it
stays quiet: "not wired here". If the ledger can't be reached it says so, keeps the
line in `unsent.json` in the plugin's data folder, and `ledger.py flush` retries it.

## 2. How Claude Code is covered

The `time-dividend` plugin's `Stop` hook runs `ledger.py hook` at the end of every
turn and re-sends the whole session (same `external_id`), so the line is current
whenever the session stops. The hook is given only the session id, the transcript
path and the folder; it reads everything else from the transcript.

- Tokens and cost: if the transcript has `cost-state` lines, the client uses them
  (`cost_basis = reported`). Cloud transcripts don't have them, so the client adds up
  each message's own `usage`, once per message id, including subagents, and prices it
  from the list-price table at the top of `ledger.py` (`estimate`). A model not in
  that table is counted in tokens but not priced (`partial`).
- A session no human typed into (started by another session or a schedule) is logged
  with AI minutes and spend; `you_minutes` is left out, not guessed.

## 3. Add an adapter for another tool (about 20 lines)

An adapter is a small script that does four things:

1. **Find what the tool really reports.** Read its docs or its log/usage output. Write
   down which of the fields above it gives you. If it gives none of the numbers,
   an adapter can still log `source`, time and `ai_minutes` (measured by your own clock).
2. **Run at the end of the session or call** (a wrapper script, a hook, a cron job
   that reads the tool's log).
3. **Build the line from only those fields.** Copy fields across. Don't fill gaps.
   No price for the tool? Leave out `cost_usd`.
4. **Pipe it to `ledger.py emit`.** It does validation, the quiet no-token rule, and the
   "can't reach the ledger" handling for you.

Worked example, a local model behind an OpenAI-compatible server (LM Studio on a Mac
is this shape): [`adapters/openai_compatible.py`](./adapters/openai_compatible.py).
**It is unverified for LM Studio**: LM Studio's docs don't show a `usage` object, so the
script is written against the generic OpenAI response and sends no token numbers if
`usage` is missing. Run it once against your LM Studio and look at the line it prints
on the ledger page before trusting it.

Tools that never expose usage (chat apps on a subscription) can't be captured
automatically; use the paste-in routes in [`elsewhere/`](./elsewhere/).
