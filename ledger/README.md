# The Ledger: time dividend

Private. For every AI job session it records **how long it would have taken a
competent human by hand** next to **how much of your own time it took** and **what the AI cost**. It also
keeps a daily plain-language log of what was done, and a **keep list**: tasks you
keep for yourself (the AI volunteers nothing on them and names a match when an assigned task
includes one), plus pre-set shares for where saved time goes, so
Parkinson's law can't quietly fill it with more work.

- **Daily page:** [labs.chiibitsu.com/ledger](https://labs.chiibitsu.com/ledger/) (magic-link login, owners only)
- **Data:** Supabase project `chiibitsu-labs`, tables `ledger_*`, row-level security on all of them
- **Later:** public human sign-off receipts in aikiri-network, linked per session via `receipt_url`

## How each tool gets logged

| Where you work | How it's recorded | What you do |
|---|---|---|
| Claude Code in the cloud | The repo's own hooks in `.claude/settings.json` (this repo has them). They record AI time, your time and any reported cost at the end of every turn; the `log-session` skill adds the human-equivalent estimate and the log lines | `LEDGER_TOKEN` in the environment (setup below) |
| Claude Code on your Mac (CLI, desktop) | The `time-dividend` plugin: the same hooks, the same client | One-time setup below |
| Claude chat & Cowork | [`elsewhere/claude-chat-skill`](./elsewhere/claude-chat-skill/SKILL.md) writes through the Supabase connector | Upload the skill once; it logs when work wraps up |
| ChatGPT | Custom instruction makes it end finished work with a JSON block | Paste the block on the page |
| Codex | `AGENTS.md` snippet runs the pinned client with your token | One-time setup |

Details for ChatGPT and Codex: [`elsewhere/chatgpt-and-codex.md`](./elsewhere/chatgpt-and-codex.md).

### Why cloud sessions use repo hooks, not the plugin

Checked on 18 Nov 2026 in a cloud session of this repo (Claude Code 2.1.327). The plugin was
never installed there, so its hooks never ran: in a cloud session, Claude Code installs
plugins at startup only from marketplaces declared in **user, `--settings` or managed
settings**. The `extraKnownMarketplaces` and `enabledPlugins` lines in a repo's
`.claude/settings.json` are set aside. The evidence: the startup log shows the install step
running with nothing to install; `~/.claude/plugins/installed_plugins.json` stayed empty and
no marketplace was registered; the same declaration installs fine from user settings in the
same container, so it is not the network. A repo's own `hooks` in `.claude/settings.json` do run
in cloud sessions (tested the same day), so that is what this repo uses. The plugin lines stay
for your Mac, where they do work. When both run, both write the same row (an upsert by
session id), so nothing doubles.

**Other repos.** Two ways, both decisions for you and the vibeOS PM, not made here:

- *Per repo:* add the same four hooks to that repo's `.claude/settings.json`, running the
  client fetched from a pinned commit with its sha256 checked first (the pin and hash vibeOS
  `CLAUDE.md` names; the vibeOS PR that moves the pin carries the exact command).
- *Per environment:* a setup script in the cloud environment that runs
  `claude plugin marketplace add chiibitsu/labs` and
  `claude plugin install time-dividend@chiibitsu-labs`, which puts the plugin in user settings
  for every repo in that environment. Untested as a whole: the install works in a cloud
  container, but whether a session then loads its hooks has not been seen yet. It also follows
  `main`, not a pin.

### Any Claude Code repo without the hooks

vibeOS's standing orders carry the exact
commands, pinned to a reviewed commit of `ledger.py` with its sha256 checked before it runs,
so a change here reaches sessions only through a vibeOS PR that moves the pin. The client
identifies the session by the harness's `CLAUDE_CODE_SESSION_ID` and reads every copy of its
transcript (Claude Code starts a new copy when the working directory changes, and the cost
records can stay in the old one). Time is merged across the copies, a line in two copies
counting once; subagent transcripts never count. Cost is recorded when the
transcript carries Claude Code's cost records, and the client says so when it cannot find them
rather than estimating. Only the top-level session logs; subagents never do.

## One-time setup (about 10 minutes)

1. **Allow the login link.** Supabase → `chiibitsu-labs` → Authentication → URL
   Configuration → Redirect URLs: add `https://labs.chiibitsu.com/ledger/`.
2. **Sign in** at labs.chiibitsu.com/ledger and create a token under
   *Intake tokens* (one per tool, e.g. "Claude Code cloud").
3. **Claude Code on the web:** add the token as an environment variable named
   `LEDGER_TOKEN` in **each** cloud environment that should log (environment menu → Edit).
   A session in an environment without it tells you, once, that the ledger is not wired, and
   logs nothing. This repo's `.claude/settings.json` already has the hooks (see
   *Why cloud sessions use repo hooks* above).

4. **Claude Code on your Mac:** `/plugin marketplace add chiibitsu/labs`, then
   `/plugin install time-dividend@chiibitsu-labs`, and set `LEDGER_TOKEN` in your
   shell profile. That variable is the only place the client looks for the token.
5. **Claude chat / Cowork:** upload `elsewhere/claude-chat-skill/SKILL.md` as a
   skill. It uses your Supabase connector.

## How the numbers work

- **AI time:** sum of gaps between AI events in the transcript, ignoring gaps of 10 min or more.
- **Your time:** for each of your prompts, the time since the AI last finished (reading
  and typing), capped at 5 min so time away doesn't count, plus 2 min for the first
  prompt and the final read. Only what you typed counts as a prompt. Texts Claude Code
  writes in your name are not: "[Request interrupted by user…]", tool results, the
  summary after a compaction, local-command caveats, task notifications, and messages
  from other sessions. None of them can become a session's title either.
- **Human-equivalent:** the AI's honest estimate, with a range and the concrete output
  it counted (`estimate_basis`). Mark estimates *too low / about right / too high* on
  the page each week; that calibration is what makes the data worth something.
- **Saved** = human-equivalent − your time. A session without an estimate isn't counted as
  saved; the page marks it **needs estimate** and counts how many are waiting, so none
  goes missing.
- **Cost & tokens:** Claude Code writes a cost total and per-model token counts into the
  transcript **only when its process ends** (a restart, or the session closing), never
  mid-session. So a session that is still running has no cost yet: the hooks record none
  rather than guess, a `SessionEnd` hook records it if the record lands before it runs, and
  the next turn after a restart picks it up. Recorded as reported (`cost_basis = reported`).
  When those totals stop more than 10 minutes before the session's last work, the cost
  misses the later work and is marked `partial`. The cloud session service does not give a
  hook its cost (checked 18 Nov 2026: no cost field for a running session, and the only route
  in is a credential file the session is not allowed to read), so there is no fallback. A session resumed in a
  fresh container holds only that container's transcript: its AI time and cost are what that
  copy records, and when it holds no prompt of yours, your minutes are left blank, not guessed. That's the API-equivalent cost: on a subscription it isn't your bill,
  but it's the honest number to set against a human's hours. The page shows cost
  per day and week, and **cost per saved hour** overall. ChatGPT and Codex
  don't report cost, so fill it in by hand if you want it (`manual`).

## When something fails

Never blocking, never silent. With no `LEDGER_TOKEN`, the session is told once that the ledger
is not wired, so it can tell you. When an automatic write fails, you see one line at the end
of that turn, and the session is told once on your next prompt. The hooks keep a small state
file per session in `~/.claude/time-dividend/`, so two sessions in one folder never mix.

**Testing a change without touching the live ledger:** create an empty file
`~/.claude/time-dividend/dry-run`. Writes then go to `dry-run.jsonl` beside it, without the
token. Tests: `python3 -I ledger/plugin/tests/test_ledger.py` (synthetic transcripts only).

## Files

- `index.html`: the private daily page
- `plugin/`: Claude Code plugin (`hooks/`, `scripts/ledger.py`, `skills/log-session/`, `tests/`)
- `../.claude/settings.json`: this repo's own hooks, which run the same client in cloud sessions
- `elsewhere/`: Claude chat/Cowork skill, ChatGPT and Codex instructions
- `../.claude-plugin/marketplace.json`: makes this repo a plugin marketplace
