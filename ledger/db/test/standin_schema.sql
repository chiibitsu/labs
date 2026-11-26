-- STAND-IN, NOT THE REAL LEDGER. The real ledger schema was created through the
-- Supabase connector and is not in any repository. This file rebuilds only what
-- the tests need, using the table and column names the ledger page
-- (ledger/index.html) and client (ledger/plugin/scripts/ledger.py) already use.
-- Column TYPES here are guesses; the migration casts every column it returns, and
-- its self-check fails the whole apply if a name is wrong on the real ledger.

-- Supabase-like roles and default grants (Supabase grants new public tables and
-- functions to anon and authenticated by default; the migration must undo that).
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;
grant usage on schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;

create table public.ledger_sessions (
  id                uuid primary key default gen_random_uuid(),
  source            text not null,
  external_id       text,
  project           text,
  title             text,            -- free text: must never come out of the door
  estimate_basis    text,            -- free text: must never come out of the door
  started_at        timestamptz,
  ended_at          timestamptz,
  ai_minutes        real,
  you_minutes       real,
  human_minutes     real,
  human_low         real,
  human_high        real,
  saved_minutes     real generated always as (human_minutes - you_minutes) stored,
  calibration       text,
  cost_usd          double precision,
  cost_basis        text,
  tokens_input      integer,
  tokens_cache_read integer,
  tokens_output     integer,
  model_usage       jsonb,
  created_at        timestamptz default now()
);
create table public.ledger_actions (
  id bigserial primary key, session_id uuid references public.ledger_sessions(id),
  at timestamptz default now(), kind text, line text
);
create table public.ledger_keep (
  id bigserial primary key, kind text, label text, why text, share real, active boolean default true, sort int
);
create table public.ledger_tokens (
  id uuid primary key default gen_random_uuid(), label text, token_hash text unique,
  revoked boolean default false, last_used_at timestamptz, created_at timestamptz default now()
);
alter table public.ledger_sessions enable row level security;
alter table public.ledger_actions  enable row level security;
alter table public.ledger_keep     enable row level security;
alter table public.ledger_tokens   enable row level security;

-- Stand-in for the write door: accepts only intake tokens from ledger_tokens.
create function public.ledger_ingest(p_token text, p_entry jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare sid uuid;
begin
  if not exists (select 1 from public.ledger_tokens
                 where token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex') and not revoked) then
    raise exception 'invalid token' using errcode = '28000';
  end if;
  insert into public.ledger_sessions (source, title) values (p_entry->>'source', p_entry->>'title') returning id into sid;
  return sid;
end $$;

-- Seed: one intake token whose plaintext the tests know, and planted free text.
insert into public.ledger_tokens (label, token_hash)
values ('intake', encode(sha256(convert_to('intake-token-test', 'UTF8')), 'hex'));

insert into public.ledger_sessions (source, project, title, estimate_basis, started_at, ended_at,
  ai_minutes, you_minutes, human_minutes, cost_usd, cost_basis, tokens_input, tokens_cache_read, tokens_output, model_usage)
select 'claude-code', 'labs', 'FREETEXT-TITLE-' || g, 'FREETEXT-BASIS-' || g,
       timestamptz '2026-11-01 00:00+08' + g * interval '1 hour',
       timestamptz '2026-11-01 00:30+08' + g * interval '1 hour',
       10 + g, 5, 60, 1.25 * g, 'reported', 1000 * g, 50 * g, 200 * g,
       jsonb_build_object('claude-opus-5-5', jsonb_build_object('inputTokens', 1000 * g, 'outputTokens', 200 * g))
from generate_series(1, 1200) g;

insert into public.ledger_actions (session_id, kind, line)
select id, 'did', 'FREETEXT-ACTION' from public.ledger_sessions limit 5;
insert into public.ledger_keep (kind, label, why, sort) values ('task', 'FREETEXT-KEEP', 'FREETEXT-WHY', 1);

-- model_usage with text hidden inside, and one that isn't an object at all.
update public.ledger_sessions set model_usage =
  '{"claude-opus-5-5": {"inputTokens": 7, "priced": true, "note": "FREETEXT-MU-NESTED"}, "summary": "FREETEXT-MU-TOP"}'
where started_at = (select min(started_at) from public.ledger_sessions);
update public.ledger_sessions set model_usage = '["FREETEXT-MU-ARRAY"]'
where started_at = (select max(started_at) from public.ledger_sessions);
