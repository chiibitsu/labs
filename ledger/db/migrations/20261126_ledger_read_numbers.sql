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
--    If the table already exists it must be one an earlier run of this file left:
--    owned by us, with no policies and no grants to anyone else. Otherwise stop,
--    because whoever can reach it could add their own token.
do $$
declare
  me oid := (select oid from pg_roles where rolname = current_user);
  t  regclass := to_regclass('public.ledger_read_tokens');
begin
  if t is not null then
    if (select relowner from pg_class where oid = t) <> me then
      raise exception 'ledger: public.ledger_read_tokens already exists and is owned by another role; stopping';
    end if;
    if exists (select 1 from pg_policy where polrelid = t) then
      raise exception 'ledger: public.ledger_read_tokens already exists with row-level policies; stopping';
    end if;
    if exists (select 1 from pg_class c, aclexplode(c.relacl) a where c.oid = t and a.grantee <> me) then
      raise exception 'ledger: public.ledger_read_tokens already exists with grants to other roles; stopping';
    end if;
  end if;
end;
$$;

create table if not exists public.ledger_read_tokens (
  id          uuid primary key default gen_random_uuid(),
  label       text not null,
  token_hash  text not null unique,          -- sha-256 hex of the token; the token itself is never stored
  revoked     boolean not null default false,
  created_at  timestamptz not null default now()
);

-- Nobody but the owner reaches this table: RLS on, no policies, and every grant
-- the database added by default (to anon, authenticated, service_role or any
-- other role) removed.
alter table public.ledger_read_tokens enable row level security;
revoke all on table public.ledger_read_tokens from public;
do $$
declare r text;
begin
  for r in
    select distinct quote_ident(pg_get_userbyid(a.grantee))
    from pg_class c, aclexplode(c.relacl) a
    where c.oid = 'public.ledger_read_tokens'::regclass
      and a.grantee <> c.relowner and a.grantee <> 0
  loop
    execute 'revoke all on table public.ledger_read_tokens from ' || r;
  end loop;
end;
$$;

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
           -- model_usage is rebuilt, not passed through. Kept: model names that
           -- look like model ids (letters, digits and . _ : / @ -, up to 100
           -- characters), and under each only these known counters, with number
           -- (or, for priced, true/false) values. Every other key and value is dropped.
           (select jsonb_object_agg(m.key, (
                     select coalesce(jsonb_object_agg(f.key, f.value), '{}'::jsonb)
                     from jsonb_each(m.value) f
                     where (f.key in ('inputTokens', 'outputTokens', 'cacheReadInputTokens',
                                      'cacheCreationInputTokens', 'costUSD')
                            and jsonb_typeof(f.value) = 'number')
                        or (f.key = 'priced' and jsonb_typeof(f.value) = 'boolean')))
              from jsonb_each(case when jsonb_typeof(s.model_usage::jsonb) = 'object'
                                   then s.model_usage::jsonb else '{}'::jsonb end) m
             where jsonb_typeof(m.value) = 'object'
               and m.key ~ '^[A-Za-z0-9][A-Za-z0-9._:/@-]{0,99}$')
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
