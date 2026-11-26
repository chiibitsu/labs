# Ledger database changes

The ledger's tables were first set up straight in Supabase, so their SQL is not in
this repo. From here on, each change to the ledger's database is a file in
`migrations/`, with tests in `test/`. Nothing here runs by itself: Chii applies each
file by hand.

## The read-only door (`20261126_ledger_read_numbers.sql`)

A script can read the ledger's **numbers** without a key that can change anything.

| | |
|---|---|
| Endpoint | `POST https://wguhmblrcfcvbheusizt.supabase.co/rest/v1/rpc/ledger_read_numbers` |
| Headers | `apikey` and `Authorization: Bearer`, both the publishable key in `plugin/scripts/ledger.py`; `Content-Type: application/json` |
| Body | `{"p_token": "<read token>", "p_limit": 1000, "p_offset": 0}` (`p_limit` 1–1000, default 500; `p_offset` default 0) |
| Secret name | `LEDGER_READ_TOKEN` |
| Returns | a JSON array, oldest session first: `started_at`, `ended_at`, `source`, `project`, `ai_minutes`, `you_minutes`, `human_minutes`, `saved_minutes`, `cost_usd`, `cost_basis`, `tokens_input`, `tokens_cache_read`, `tokens_output`, `model_usage` |
| Paging | keep adding `p_limit` to `p_offset` until a page comes back shorter than `p_limit` |
| Bad or revoked token | an error, never an empty list (Postgres code 28000; expected to arrive as HTTP 403, not yet seen on the real ledger) |

Never returned: session titles, estimate notes, the action log, the keep list, or
any column added to sessions later (the list above is fixed in the function).

**Read tokens are separate from intake tokens.** They live in their own table,
`ledger_read_tokens`, which the API cannot see or change. An intake token can't
open this door, and a read token can't write through any door.

**If a read token leaks**, whoever holds it can see, for every session: when it
ran, which tool, the project name, the minutes, the cost and the per-model token
counts. They cannot see what was done or said, and cannot add, change or delete
anything. Revoke it (below) and mint a new one.

### Chii's SQL editor lines

Supabase → `chiibitsu-labs` → SQL Editor:

- **Check first** (read-only, changes nothing): paste
  `migrations/20261126_ledger_read_numbers.precheck.sql` → Run. One row comes back.
  `SAFE TO RUN` with problems `none` means go ahead; `DO NOT RUN YET` lists what differs.
- **Apply:** paste `migrations/20261126_ledger_read_numbers.sql` → Run.
- **Make a read token** (shows it once; only its fingerprint is kept):
  `select public.ledger_new_read_token('nightly export');`
- **Revoke it:** `select public.ledger_revoke_read_token('nightly export');`
  (returns how many it revoked; intake tokens are not touched)

Neither line works through the API, only in the SQL editor.

## Tests

`bash ledger/db/test/run.sh` builds a throwaway local Postgres with a **stand-in**
ledger (`test/standin_schema.sql`: the table and column names the ledger page and
client already use; the column types are guesses), applies the migration twice and
checks the door. It never touches the real ledger.
