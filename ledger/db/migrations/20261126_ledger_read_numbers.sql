-- Ledger: a read-only door for scripts. Numbers and project only.
--
-- What this adds (and nothing else):
--   1. public.ledger_read_tokens        its own table of read tokens (hashes only)
--   2. public.ledger_read_numbers(...)  the door: returns a fixed list of number
--                                       columns from ledger_sessions, never free text
--   3. public.ledger_new_read_token()   mint a read token (SQL editor only)
--   4. public.ledger_revoke_read_token() revoke one   (SQL editor only)
--
-- What this does NOT touch: ledger_tokens, ledger_ingest, ledger_keep_for,
-- ledger_record, ledger_add, ledger_create_token, any table's rows or policies.
--
-- Apply: Supabase -> chiibitsu-labs -> SQL Editor -> paste this whole file -> Run.
-- It is one transaction. If any ledger column it reads is named differently than
-- the ledger page expects, the self-check at the end fails and NOTHING is kept.
-- Safe to run twice.

begin;

-- 0. Any function this file replaces must already be ours. CREATE OR REPLACE keeps
--    an existing owner, and that owner could later rewrite the door.
do $$
declare bad text;
begin
  select string_agg(p.oid::regprocedure::text || ' (owned by ' || pg_get_userbyid(p.proowner) || ')', ', ')
    into bad
  from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public'
    and p.proname in ('ledger_read_numbers', 'ledger_new_read_token', 'ledger_revoke_read_token')
    and p.proowner <> (select oid from pg_roles where rolname = current_user);
  if bad is not null then
    raise exception 'ledger: these functions already exist and are owned by another role: %; stopping', bad;
  end if;
end;
$$;

-- 1. Read tokens live in their own table, apart from the write (intake) tokens,
--    so a read token is never accepted by a write function and can be revoked
--    without touching any write token.
create table if not exists public.ledger_read_tokens (
  id          uuid primary key default gen_random_uuid(),
  label       text not null,
  token_hash  text not null unique,          -- sha-256 hex of the token; the token itself is never stored
  revoked     boolean not null default false,
  created_at  timestamptz not null default now()
);

-- If the table already existed, it must be ours (from an earlier run of this file).
-- A table owned by another role would let that role add its own token.
do $$
begin
  if (select c.relowner from pg_class c where c.oid = 'public.ledger_read_tokens'::regclass)
     <> (select oid from pg_roles where rolname = current_user) then
    raise exception 'ledger: public.ledger_read_tokens already exists and is owned by another role; stopping';
  end if;
end;
$$;

-- Nobody reaches this table through the API: RLS on, no policies, no grants.
alter table public.ledger_read_tokens enable row level security;
revoke all on table public.ledger_read_tokens from public, anon, authenticated;

-- 2. The door. Fixed column list: a column added to ledger_sessions later is
--    never returned unless someone edits this list. STABLE: Postgres refuses any
--    insert, update or delete inside it, whatever it is passed.
create or replace function public.ledger_read_numbers(
  p_token  text,
  p_limit  integer default 500,
  p_offset integer default 0
)
returns table (
  started_at        timestamptz,
  ended_at          timestamptz,
  source            text,
  project           text,
  ai_minutes        numeric,
  you_minutes       numeric,
  human_minutes     numeric,
  saved_minutes     numeric,
  cost_usd          numeric,
  cost_basis        text,
  tokens_input      bigint,
  tokens_cache_read bigint,
  tokens_output     bigint,
  model_usage       jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_token is null or not exists (
    select 1
    from public.ledger_read_tokens t
    where t.token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
      and not t.revoked
  ) then
    raise exception 'ledger: read token not valid' using errcode = '28000';
  end if;

  return query
    select s.started_at::timestamptz,
           s.ended_at::timestamptz,
           s.source::text,
           s.project::text,
           s.ai_minutes::numeric,
           s.you_minutes::numeric,
           s.human_minutes::numeric,
           s.saved_minutes::numeric,
           s.cost_usd::numeric,
           s.cost_basis::text,
           s.tokens_input::bigint,
           s.tokens_cache_read::bigint,
           s.tokens_output::bigint,
           -- model_usage is rebuilt, not passed through: model name -> only its
           -- number and true/false fields. Any text inside it is dropped.
           (select jsonb_object_agg(m.key, (
                     select coalesce(jsonb_object_agg(f.key, f.value), '{}'::jsonb)
                     from jsonb_each(m.value) f
                     where jsonb_typeof(f.value) in ('number', 'boolean')))
              from jsonb_each(case when jsonb_typeof(s.model_usage::jsonb) = 'object'
                                   then s.model_usage::jsonb else '{}'::jsonb end) m
             where jsonb_typeof(m.value) = 'object')
    from public.ledger_sessions s
    order by s.started_at nulls last, s.id
    limit  least(greatest(coalesce(p_limit, 500), 1), 1000)
    offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.ledger_read_numbers(text, integer, integer) from public, anon, authenticated;
grant execute on function public.ledger_read_numbers(text, integer, integer) to anon;

-- 3. Mint a read token. Returns the token ONCE; only its hash is kept.
--    Not callable through the API: run it in the SQL editor.
create or replace function public.ledger_new_read_token(p_label text)
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  tok text := 'ldr_' || replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if coalesce(trim(p_label), '') = '' then
    raise exception 'ledger: give the read token a label, e.g. ''nightly export''';
  end if;
  insert into public.ledger_read_tokens (label, token_hash)
  values (trim(p_label), encode(sha256(convert_to(tok, 'UTF8')), 'hex'));
  return tok;
end;
$$;

-- 4. Revoke every read token with this label. Write tokens are untouched.
create or replace function public.ledger_revoke_read_token(p_label text)
returns integer
language sql
volatile
set search_path = ''
as $$
  with r as (
    update public.ledger_read_tokens set revoked = true
    where label = trim(p_label) and not revoked
    returning 1
  )
  select count(*)::integer from r;
$$;

revoke all on function public.ledger_new_read_token(text)    from public, anon, authenticated;
revoke all on function public.ledger_revoke_read_token(text) from public, anon, authenticated;

-- 5. Self-check: run the door once with a throwaway token, then remove it.
--    If a ledger column is missing or named differently, this raises and the
--    whole migration rolls back.
do $$
declare
  tok text := public.ledger_new_read_token('migration self-check');
begin
  perform * from public.ledger_read_numbers(tok, 1, 0);
  delete from public.ledger_read_tokens
  where token_hash = encode(sha256(convert_to(tok, 'UTF8')), 'hex');
end;
$$;

commit;

-- Tell the API about the new function.
notify pgrst, 'reload schema';
