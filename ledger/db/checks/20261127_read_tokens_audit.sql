-- Read-only audit of the read tokens on a ledger where the door is already applied.
-- Shows each token's label, when it was made and whether it is revoked. Never shows
-- a token or its fingerprint. Changes nothing.
--
-- Supabase -> chiibitsu-labs -> SQL Editor -> paste this file -> Run.
-- Expected: only tokens you made with ledger_new_read_token (e.g. 'nightly export').
-- Any active row you don't recognise: revoke it with
--   select public.ledger_revoke_read_token('<its label>');
select label,
       created_at,
       revoked,
       case when revoked then 'revoked' else 'ACTIVE: opens the door' end as status
from public.ledger_read_tokens
order by created_at;
