# Logging ChatGPT and Codex sessions

Both land in the same ledger as Claude. Pick the path that fits the tool.

## ChatGPT (chat): paste-in

Add this to ChatGPT → Settings → Personalization → Custom instructions
("How would you like ChatGPT to respond?"):

```text
When I say "log it", reply with only a JSON code block for my time ledger, no prose:
{"source":"chatgpt","title":"<what this chat produced>",
 "human_minutes":<minutes a competent professional would need to produce the same output by hand>,
 "human_low":<low>,"human_high":<high>,
 "estimate_basis":"<the concrete output counted: words, sources, files, tables>",
 "you_minutes":<your best guess of my own minutes: each of my messages ≈ 2–5 min>,
 "tokens_input":<approx input tokens if you can tell, else omit>,"tokens_output":<approx output tokens, else omit>,
 "actions":[{"kind":"did|drafted|handled|handed_back|note","line":"<plain past-tense line>"}]}
Be honest, not generous, with human_minutes.
```

Then copy the block into **labs.chiibitsu.com/ledger → Add an entry**. Fix any number
before saving.

## Codex (cloud tasks or CLI): automatic

1. Create an intake token on the ledger page (Intake tokens → New token).
2. Add it to the Codex environment as a secret named `LEDGER_TOKEN`.
3. Add this to the repo's `AGENTS.md`:

```markdown
## Time Dividend ledger
When a task is done, record it (skip silently if `$LEDGER_TOKEN` is empty):

curl -s -X POST "https://wguhmblrcfcvbheusizt.supabase.co/rest/v1/rpc/ledger_ingest" \
  -H "apikey: sb_publishable_Y_jI74qFxdAlZb4elby75A_7QlUky9a" \
  -H "Content-Type: application/json" \
  -d "{\"p_token\":\"$LEDGER_TOKEN\",\"p_entry\":{\"source\":\"codex\",\"title\":\"...\",
       \"ai_minutes\":<your working minutes>,\"human_minutes\":<honest human-equivalent minutes>,
       \"human_low\":<low>,\"human_high\":<high>,\"estimate_basis\":\"<files/lines/tests counted>\",
       \"tokens_input\":<input tokens used, if known>,\"tokens_output\":<output tokens, if known>,
       \"actions\":[{\"kind\":\"did\",\"line\":\"...\"}]}}"

Keep list: before starting, read it and never do anything on it; leave it for her and
add a `handed_back` action saying so:

curl -s -X POST "https://wguhmblrcfcvbheusizt.supabase.co/rest/v1/rpc/ledger_keep_for" \
  -H "apikey: sb_publishable_Y_jI74qFxdAlZb4elby75A_7QlUky9a" \
  -H "Content-Type: application/json" \
  -d "{\"p_token\":\"$LEDGER_TOKEN\"}"
```

Your own minutes on a Codex task are usually the review: add or correct
`you_minutes` on the ledger page after you've reviewed the PR.

**Cost:** ChatGPT and Codex don't hand their cost to the conversation. Token counts
are logged when the tool can tell. For dollars, fill in `cost` on the session (edit)
from your OpenAI usage page if you want it, and it's marked `manual`.
