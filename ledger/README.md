# The Ledger: time dividend

Private. For every AI job session it records **how long it would have taken a
competent human by hand** next to **how much of your own time it took** and **what the AI cost**. It also
keeps a daily plain-language log of what was done, and a **keep list**: tasks the
AI hands back to you, plus pre-set shares for where saved time goes, so
Parkinson's law can't quietly fill it with more work.

- **Daily page:** [labs.chiibitsu.com/ledger](https://labs.chiibitsu.com/ledger/) (magic-link login, owners only)
- **Data:** Supabase project `chiibitsu-labs`, tables `ledger_*`, row-level security on all of them
- **Later:** public human sign-off receipts in aikiri-network, linked per session via `receipt_url`

## How each tool gets logged

| Where you work | How it's recorded | What you do |
|---|---|---|
| Claude Code (cloud, CLI, desktop) | `time-dividend` plugin. Hooks record AI time and your time automatically; the `log-session` skill adds the human-equivalent estimate and the log lines | One-time setup below |
| Claude chat & Cowork | [`elsewhere/claude-chat-skill`](./elsewhere/claude-chat-skill/SKILL.md) writes through the Supabase connector | Upload the skill once, say "log it" |
| ChatGPT | Custom instruction makes it reply with a JSON block | Say "log it", paste the block on the page |
| Codex | `AGENTS.md` snippet posts with your token | One-time setup |

Details for ChatGPT and Codex: [`elsewhere/chatgpt-and-codex.md`](./elsewhere/chatgpt-and-codex.md).

**Any Claude Code repo without the plugin** (the canon rule in vibeOS points here): with
`LEDGER_TOKEN` in the environment, fetch the client and record the entry. It finds the
session's transcript itself, so time, cost and tokens still come from the real record:

```bash
curl -fsSL https://raw.githubusercontent.com/chiibitsu/labs/main/ledger/plugin/scripts/ledger.py -o /tmp/ledger.py
python3 /tmp/ledger.py keep            # the keep list, before starting work
python3 /tmp/ledger.py entry <<'JSON'  # when the work is done
{"title": "...", "human_minutes": 180, "human_low": 120, "human_high": 240,
 "estimate_basis": "...", "actions": [{"kind": "did", "line": "..."}]}
JSON
```

## One-time setup (about 10 minutes)

1. **Allow the login link.** Supabase → `chiibitsu-labs` → Authentication → URL
   Configuration → Redirect URLs: add `https://labs.chiibitsu.com/ledger/`.
2. **Sign in** at labs.chiibitsu.com/ledger and create a token under
   *Intake tokens* (one per tool, e.g. "Claude Code cloud").
3. **Claude Code on the web:** add the token to your cloud environment as an
   environment variable named `LEDGER_TOKEN` (environment menu → Edit). Any repo
   that should log sessions needs this in `.claude/settings.json` (this repo
   already has it):

   ```json
   {
     "extraKnownMarketplaces": { "chiibitsu-labs": { "source": { "source": "github", "repo": "chiibitsu/labs" } } },
     "enabledPlugins": { "time-dividend@chiibitsu-labs": true }
   }
   ```

4. **Claude Code on your Mac:** `/plugin marketplace add chiibitsu/labs`, then
   `/plugin install time-dividend@chiibitsu-labs`. It asks for the token
   (stored securely), or set `LEDGER_TOKEN` in your shell.
5. **Claude chat / Cowork:** upload `elsewhere/claude-chat-skill/SKILL.md` as a
   skill. It uses your Supabase connector.

## How the numbers work

- **AI time:** sum of gaps between AI events in the transcript, ignoring gaps over 10 min.
- **Your time:** for each of your prompts, the time since the AI last finished (reading
  and typing), capped at 5 min so time away doesn't count, plus 2 min for the first
  prompt and the final read.
- **Human-equivalent:** the AI's honest estimate, with a range and the concrete output
  it counted (`estimate_basis`). Mark estimates *too low / about right / too high* on
  the page each week; that calibration is what makes the data worth something.
- **Saved** = human-equivalent − your time. Sessions without an estimate aren't counted.
- **Cost & tokens:** Claude Code writes a running cost total and per-model token
  counts into every transcript; the hook records them as reported (`cost_basis =
  reported`). That's the API-equivalent cost: on a subscription it isn't your bill,
  but it's the honest number to set against a human's hours. The page shows cost
  per day and week, and **cost per saved hour** overall. ChatGPT and Codex
  don't report cost, so fill it in by hand if you want it (`manual`).

## Files

- `index.html`: the private daily page
- `plugin/`: Claude Code plugin (`hooks/`, `scripts/ledger.py`, `skills/log-session/`)
- `elsewhere/`: Claude chat/Cowork skill, ChatGPT and Codex instructions
- `../.claude-plugin/marketplace.json`: makes this repo a plugin marketplace
