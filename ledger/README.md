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
| Claude Code in the cloud (a session with this one repo, outside a Project) | The repo's own hooks in `.claude/settings.json` (this repo has them). They record AI time, your time and any reported cost at the end of every turn; the `log-session` skill adds the human-equivalent estimate and the log lines | `LEDGER_TOKEN` in the environment (setup below) |
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
in a cloud session with one repository (tested the same day), so that is what this repo uses.

**Where repo hooks do not reach** (Claude Code's
[settings](https://code.claude.com/docs/en/settings#settings-in-cloud-sessions) and
[cloud environment](https://code.claude.com/docs/en/cloud-environments) docs, read 18 Nov 2026):
a cloud thread inside a **Project** ignores a repo's hooks, and a session with **several
repositories** reads only the plugin keys, not hooks. Those sessions record nothing
automatically; log them by hand with `entry` until the route below is in place. The docs also
say user-level settings never reach a cloud session, and that the hooks an Anthropic-hosted
cloud session runs come only from the repo and from the organization's **server-managed
settings** (claude.ai admin console). Server-managed settings are therefore the documented
route to every cloud session, Project threads and multi-repo sessions included. The plugin lines stay
for your Mac, where they do work. When both run, both write the same row (an upsert by
session id), so nothing doubles.

**Other repos.** Options, all decisions for you and the vibeOS PM, not made here:

- *Per repo:* add the same four hooks to that repo's `.claude/settings.json`, running the
  client fetched from a pinned commit with its sha256 checked first (the pin and hash in vibeOS
  `templates/claude-md.md`, "Log the work"; the vibeOS PR that moves the pin carries the exact command).
- *Organization-wide:* the same four hooks in the organization's server-managed settings,
  running the pinned, hash-checked client. Reaches every cloud session, per the docs above.
  Not yet tested.
- *Per environment (setup script installing the plugin):* per the docs above, a cloud
  session does not run user-level hooks, so this route is expected **not** to work. Kept
  here only so nobody tries it unknowingly.

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
   A session in an environment without it tells you that the ledger is not wired, and
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
- **Your time is measured only in Claude Code.** A figure from ChatGPT, Codex or Claude chat
  is that AI's guess (or your own edit), and the page shows it as *not measured*.
- **Human-equivalent:** the AI's honest estimate, with a range and the concrete output
  it counted (`estimate_basis`). Mark estimates *too low / about right / too high* on
  the page each week; that calibration is what makes the data worth something.
- **What the page leads with**, for every entry and every total: **time invested** (your
  measured minutes, shown for every entry, thinking sessions included), **AI cost**, and
  **time saved**. Time saved is human-equivalent − your time, and only where both exist: an
  honest estimate of a concrete output *and* your measured minutes. Totals of time saved are
  labelled as an estimate, with the range from each estimate's low and high. An entry with
  no estimate shows as **time invested only**, not as missing; one whose minutes are unknown
  says so, and claims nothing saved.
- **Cost & tokens:** Claude Code writes a cost total and per-model token counts into the
  transcript at points of its own choosing: at the latest when its process ends (a restart,
  or the session closing), and in one cloud session seen 21 Nov 2026 several times
  mid-session too (why is untested). Until the first one, a session has no cost: the hooks
  record none rather than guess, and a later turn or the `SessionEnd` hook picks it up. The
  newest record counts. Recorded as reported (`cost_basis = reported`). When the newest
  record sits more than 10 minutes before the session's last work, the cost misses the later
  work and is marked `partial`. A session's own entry never sets cost, tokens or time: the
  client measures them and drops any it is given. The cloud session service does not give a
  hook its cost (checked 18 Nov 2026: no cost field for a running session, and the only route
  in is a credential file the session is not allowed to read), so there is no fallback. A session resumed in a
  fresh container holds only that container's transcript: its AI time and cost are what that
  copy records, and when it holds no prompt of yours, your minutes are left blank, not guessed. That's the API-equivalent cost: on a subscription it isn't your bill,
  but it's the honest number to set against a human's hours. The page shows cost
  per day and week, and **cost per saved hour** overall. Totals count only known values: the
  small line under each says how many entries are unknown, not measured, not reported or
  partial, and a total with nothing known shows "—". ChatGPT and Codex
  don't report cost, so fill it in by hand if you want it (`manual`).

## When something fails

Never blocking, never silent. With no `LEDGER_TOKEN`, the session is told at its start and on
your first prompt that the ledger is not wired, so it can tell you. When an automatic write
fails, you see one line at the end of that turn, and the session is told once on your next
prompt. A failure in the final write as a session closes, which no later prompt of that
session can tell, is told on the next prompt of any session on that machine. If the hook
itself breaks, you see one line saying so. The hooks keep a small state
file per session in `~/.claude/time-dividend/`, so two sessions in one folder never mix.

**Testing a change without touching the live ledger:** create an empty file
`~/.claude/time-dividend/dry-run`. While it is there, this version of the client writes to
`dry-run.jsonl` beside it instead of the ledger, needs no token, and does not read the keep
list. It applies to every session on that machine, and each one is told it is in dry-run, so a
forgotten file is never silent. **Delete the file when you are done**, or nothing is recorded.
It covers only this version of the client: an older installed `time-dividend` plugin, and the
pinned client vibeOS's standing orders run, ignore it and write for real, so disable the plugin
(`/plugin disable time-dividend`) and skip those pinned commands while testing.
Tests: `python3 -I ledger/plugin/tests/test_ledger.py` (synthetic transcripts only).

## Files

- `index.html`: the private daily page
- `plugin/`: Claude Code plugin (`hooks/`, `scripts/ledger.py`, `skills/log-session/`, `tests/`)
- `../.claude/settings.json`: this repo's own hooks, which run the same client in cloud sessions
- `elsewhere/`: Claude chat/Cowork skill, ChatGPT and Codex instructions
- `../.claude-plugin/marketplace.json`: makes this repo a plugin marketplace
