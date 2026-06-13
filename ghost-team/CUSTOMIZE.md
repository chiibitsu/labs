# Make the Ghost Team your own

The default team is a *generic* solo-founder team. Ten minutes of
customization turns it into *your* company's team. Here's the order I'd do it in.

## 1. Give them your context (highest leverage)

Each agent file is a system prompt. Open the ones you'll use most and add a few
lines about your actual company near the top — what you're building, who it's
for, and your constraints. Two sentences of real context beats any amount of
generic advice.

```markdown
## About this company
We're building <product> for <who>. We charge <pricing>. We're pre-revenue with
~<n> months of runway. Our edge is <thing>. Stack: <stack>. Voice: <plain / playful / technical>.
```

Even better: put shared context in a top-level **`CLAUDE.md`** in your project so
*every* teammate (and Claude itself) sees it, and keep agent files for
role-specific instincts.

## 2. Rename and re-cast teammates

The `name` is how you call them (`ask the growth-marketer to…`). Change it to
whatever feels natural. You can also give them a personality — a teammate that
writes the way you'd want your brand to sound is more useful than a neutral one.

To rename: change the `name:` field **and** the filename to match (kebab-case),
then re-run `./install.sh`.

## 3. Tune the `description` — it controls auto-delegation

Claude reads each agent's `description` to decide when to call it automatically.
- Make it **specific** with trigger phrases ("Use when… write copy, landing
  pages, launch…"). Vague descriptions get ignored or misfire.
- Add **"Use PROACTIVELY"** to a description if you want Claude to reach for that
  teammate without being asked (the `chief-of-staff` uses this).

## 4. Add or remove roles

This team is opinionated, not sacred. Common moves:
- **Solo dev, no marketing yet?** Delete `growth-marketer` and `designer` for now.
- **Agency or services founder?** Add a `client-manager` or `proposal-writer`.
- **Content business?** Add an `editor` and a `seo-specialist`.

To add one, copy an existing file, change the `name`, `description`, and body,
and re-install. Tip: the fastest way to draft a new teammate is to ask Claude —
run `/agents` → *Create New Agent* and describe the role; it generates the file
for you, then you edit.

## 5. Pick the right model per teammate

Add a `model:` line to the frontmatter:
- `opus` — heavy thinking: strategy, architecture, the chief-of-staff. (More
  capable, costs more.)
- `sonnet` — the balanced default for most execution work.
- `haiku` — fast, cheap, great for high-volume or simple drafting.
- omit it — inherits whatever model you're running.

On a tight budget, reserve `opus` for `founder-coach` and `chief-of-staff` and
let the rest inherit or run `sonnet`/`haiku`.

## 6. Decide what each teammate can touch (`tools`)

By default (no `tools:` line) an agent **inherits all tools**, including any MCP
servers you've connected — that's what makes them powerful. To narrow a
teammate to read-only research, list only safe tools:

```markdown
tools: Read, Grep, Glob, WebSearch, WebFetch
```

A good rule: give the `product-engineer` full tools, and consider restricting
agents whose job is to *think*, not *change things* (`founder-coach`,
`customer-researcher`) so they can't accidentally edit code.

## 7. Wire in your real stack (MCP)

The agents already say "use the integration if it exists." Connect your tools so
that's true — see the MCP table in the [README](./README.md#plug-in-your-real-tools-mcp).
Then make the instruction concrete in the relevant agent, e.g. in
`ops-finance.md`: *"Create invoices in Stripe; never track payments by hand."*

---

## Quick reference: the frontmatter

```markdown
---
name: kebab-case-name          # required — how you call them
description: when to use them   # required — drives auto-delegation
model: opus | sonnet | haiku    # optional — omit to inherit
tools: Read, Edit, Bash         # optional — omit to inherit ALL tools + MCP
---
The system prompt goes here.
```

After any change, re-run `./install.sh` (or edit the copies already in your
project's `.claude/` directly), then `/agents` in Claude Code to confirm the
team looks right.
