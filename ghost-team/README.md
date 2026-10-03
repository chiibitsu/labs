# 👻 Ghost Team

**A starter team of Claude Code sub-agents for solo founders.**

You're one person doing the work of a company. This is the team you'd hire if
you could — a chief of staff and six specialists — built as
[Claude Code sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents)
you can talk to, delegate real work to, and reshape into your own.

It's meant to be forked. Grab it, change the names and instincts to fit *your*
company, and make it yours. If you're a founder friend reading this: **start
here.**

> ### 👀 See it work first → [**Ghost Office**](https://labs.chiibitsu.com/ghost-team/)
> Not sure what "sub-agents" even means? Play the demo. Pitch a company in one
> sentence and watch the team actually get to work — a live build log — and
> **ship you a real landing page** you can preview and download. No install, no
> account. It's free and scripted by default; flip on **⚡ Real AI**, choose a
> provider (**Claude, OpenAI, or OpenRouter** — one OpenRouter key gets you any
> model), name a model, and paste your own key to have a real model build it
> (your key stays in your browser). Then come back here to run them for real.

---

## The team

| Teammate | Hire them when you need to… |
|---|---|
| 🧭 **chief-of-staff** | turn a fuzzy goal into a plan and hand the pieces to the right specialist. Your first call on anything non-trivial. |
| 🔧 **product-engineer** | design and ship the product — architecture, code, deploy, debugging, stack trade-offs. |
| 📣 **growth-marketer** | position the product and get it in front of people — copy, landing pages, launch plans, first 100 users. |
| 🔍 **customer-researcher** | talk to users and turn the mess into patterns — interviews, surveys, feedback synthesis, JTBD. |
| 🎨 **designer** | make it feel obvious and trustworthy — UX flows, UI, brand, visual assets. |
| 📊 **ops-finance** | stay alive — runway math, pricing, metrics, invoicing, the legal basics. |
| 🧠 **founder-coach** | think clearly under pressure — hard calls, prioritization, strategy, the question that reframes the problem. |

The chief-of-staff knows the others and will **delegate to them**, so you can
hand it a whole goal ("help me launch the export feature this week") and let the
team route the work.

---

## Install — no terminal required

You don't need the command line. The fastest way is to have Claude install the
team **for** you:

1. **Open Claude Code** — on the web at
   [claude.ai/code](https://claude.ai/code) (nothing to install), or the desktop
   app / your IDE extension. Sign in with your **Claude account** — it runs on
   your Pro/Max subscription, no API key.
2. **Connect your project's GitHub repo** (or start a fresh one).
3. **Paste this prompt:**

   > Add the Ghost Team sub-agents to this project: copy the `agents/` and
   > `commands/` folders from
   > `github.com/chiibitsu/labs/tree/main/ghost-team` into my `.claude/`
   > directory, then run `/standup`.

That's it — Claude copies the files in and the team is live. It's
**model-agnostic**: the team runs on whatever model you've selected.

<details>
<summary><b>Prefer the terminal?</b></summary>

Pull just this folder (no labs repo history) and run the installer:

```bash
npx degit chiibitsu/labs/ghost-team my-ghost-team
cd my-ghost-team
./install.sh                  # into the current project's ./.claude
./install.sh --global         # into ~/.claude (every project)
./install.sh /path/to/project # into a specific project
```

No Node? Just copy `agents/*.md` into `.claude/agents/` and `commands/*.md`
into `.claude/commands/`. Same result.
</details>

---

## Use it

Open Claude Code in that project and either **call a teammate by name** or run a
**slash command**:

```
"ask the growth-marketer to write a Show HN post for my app"
"have the product-engineer add CSV export and deploy it"
"founder-coach: should I keep building or go talk to users?"
```

```
/standup            plan today and delegate it across the team
/ship <idea>        take something from concept to shipped, end to end
/validate <idea>    pressure-test an assumption before you build it
```

Claude also picks teammates **automatically** when a request fits one — that's
what the `description` line at the top of each agent file controls. Run
`/agents` inside Claude Code to see the roster and edit it in place.

---

## Plug in your real tools (MCP)

Each teammate gets sharper when it can touch your actual stack. The agents are
written to *reach for integrations when they exist* — the researcher will pull
real call transcripts, ops-finance will create real invoices, the designer will
generate real assets — if you've connected the matching
[MCP server](https://docs.claude.com/en/docs/claude-code/mcp):

| Teammate | Pairs well with |
|---|---|
| customer-researcher | meeting recorder (Fathom), forms (Tally), CRM, email |
| ops-finance | payments (Stripe), spreadsheets/CRM (Airtable) |
| designer | design tools (Canva) |
| growth-marketer | email, social, analytics |
| chief-of-staff | calendar, Notion, email — to schedule and write things down |

Connect what you use; the team adapts. Nothing here is hard-wired to a specific
provider — that's deliberate, so the kit stays yours.

---

## Make it yours

This is a starting point, not a finished product. The whole point is to fork it.
See **[CUSTOMIZE.md](./CUSTOMIZE.md)** for how to rename teammates, change their
instincts, add or remove roles, restrict tools, and wire in your context. It
takes about ten minutes to make this feel like *your* company's team.

---

## How it works (the 30-second version)

A sub-agent is just a Markdown file with a little YAML header:

```markdown
---
name: growth-marketer
description: when Claude should call this teammate
model: opus        # optional — omit to inherit your default
tools: Read, Edit  # optional — omit to inherit all tools (including your MCP)
---

The system prompt: who this teammate is and how they work.
```

Claude Code reads every file in `.claude/agents/`, and when a request matches a
`description` (or you name the agent), it spins up a fresh context with that
file as the instructions. Each teammate thinks in its own window, so they don't
crowd each other — exactly like real specialists who only load the context
their job needs.

```
labs/ghost-team/
├── README.md          ← you are here
├── CUSTOMIZE.md       ← make the team your own
├── install.sh         ← copies the team into your project's .claude/
├── agents/            ← the seven teammates (one .md each)
└── commands/          ← /standup, /ship, /validate
```

---

Part of [Chiibitsu Labs](../README.md). Fork it, break it, make it yours.
