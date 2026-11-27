-- Read-only pre-check for 20261126_ledger_read_numbers.sql. Run this FIRST.
-- It reads the database's own catalogue (names and types) and counts rows in
-- ledger_read_tokens if that table already exists. It changes nothing and reads
-- no ledger sessions.
--
-- Supabase -> chiibitsu-labs -> SQL Editor -> paste this file -> Run.
-- One row comes back:
--   verdict = SAFE TO RUN      -> go ahead with the migration
--   verdict = DO NOT RUN YET   -> paste the row back; `problems` says what differs
with need(col, kind) as (values
  ('id',                'key'),
  ('started_at',        'time'),
  ('ended_at',          'time'),
  ('source',            'text'),
  ('project',           'text'),
  ('cost_basis',        'text'),
  ('ai_minutes',        'number'),
  ('you_minutes',       'number'),
  ('human_minutes',     'number'),
  ('saved_minutes',     'number'),
  ('cost_usd',          'number'),
  ('tokens_input',      'whole'),
  ('tokens_cache_read', 'whole'),
  ('tokens_output',     'whole'),
  ('model_usage',       'json')
),
have as (
  select n.col, n.kind, c.data_type, c.udt_name
  from need n
  left join information_schema.columns c
    on c.table_schema = 'public' and c.table_name = 'ledger_sessions' and c.column_name = n.col
),
col_problems as (
  select col || case when data_type is null then ' is missing'
                     else ' is ' || data_type || ' (door expects ' || kind || ')' end as p
  from have
  where data_type is null
     or (kind = 'time'   and data_type not in ('timestamp with time zone', 'timestamp without time zone', 'date'))
     or (kind = 'text'   and data_type not in ('text', 'character varying', 'character', 'USER-DEFINED'))
     or (kind = 'number' and data_type not in ('numeric', 'real', 'double precision', 'integer', 'bigint', 'smallint'))
     or (kind = 'whole'  and data_type not in ('integer', 'bigint', 'smallint', 'numeric'))
     or (kind = 'json'   and data_type not in ('jsonb', 'json'))
     or (kind = 'key'    and data_type not in ('uuid', 'bigint', 'integer', 'text', 'character varying'))
),
other_problems as (
  select 'Postgres ' || current_setting('server_version') || ' is older than 13' as p
  where current_setting('server_version_num')::int < 130000
  union all
  select 'a table named ledger_read_tokens already exists with a different shape'
  where to_regclass('public.ledger_read_tokens') is not null
    and (select string_agg(column_name || ' ' || data_type, ', ' order by column_name)
           from information_schema.columns
          where table_schema = 'public' and table_name = 'ledger_read_tokens')
        is distinct from
        'created_at timestamp with time zone, id uuid, label text, revoked boolean, token_hash text'
  union all
  select 'ledger_read_tokens already exists and is owned by ' || pg_get_userbyid(c.relowner) || ', not ' || current_user
  from pg_class c
  where c.oid = to_regclass('public.ledger_read_tokens')
    and c.relowner <> (select oid from pg_roles where rolname = current_user)
  union all
  select 'ledger_read_tokens already exists with row-level policies'
  where exists (select 1 from pg_policy where polrelid = to_regclass('public.ledger_read_tokens'))
  union all
  select 'ledger_read_tokens already exists with grants to ' || string_agg(distinct pg_get_userbyid(a.grantee), ', ')
  from pg_class c, aclexplode(c.relacl) a
  where c.oid = to_regclass('public.ledger_read_tokens') and a.grantee <> c.relowner
  having count(*) > 0
  union all
  select 'a function named ' || p.oid::regprocedure::text || ' already exists'
         || case when p.proowner <> (select oid from pg_roles where rolname = current_user)
                 then ' and is owned by ' || pg_get_userbyid(p.proowner) else ' with a different shape' end
  from pg_proc p
  join pg_namespace ns on ns.oid = p.pronamespace
  join (values
    ('ledger_read_numbers', 'p_token text, p_limit integer, p_offset integer',
     'TABLE(started_at timestamp with time zone, ended_at timestamp with time zone, source text, project text, '
     'ai_minutes numeric, you_minutes numeric, human_minutes numeric, saved_minutes numeric, cost_usd numeric, '
     'cost_basis text, tokens_input bigint, tokens_cache_read bigint, tokens_output bigint, model_usage jsonb)'),
    ('ledger_new_read_token',    'p_label text', 'text'),
    ('ledger_revoke_read_token', 'p_label text', 'integer')
  ) as want(name, args, result) on want.name = p.proname
  where ns.nspname = 'public'
    and (   p.proowner <> (select oid from pg_roles where rolname = current_user)
         or p.prokind <> 'f'
         or pg_get_function_identity_arguments(p.oid) <> want.args
         or pg_get_function_result(p.oid) <> want.result)
),
token_rows as (
  -- A first install must start with no read tokens: any token already there was
  -- not made by ledger_new_read_token and would open the door at once.
  select (xpath('/row/n/text()',
          query_to_xml('select count(*) as n from public.ledger_read_tokens', false, true, '')))[1]::text::int as n
  where to_regclass('public.ledger_read_tokens') is not null
),
row_problems as (
  select 'ledger_read_tokens already holds ' || n || ' token(s); a first install needs it empty (if you already applied the door and made these tokens yourself, you do not need to run it again)' as p
  from token_rows where n > 0
),
all_problems as (select p from col_problems union all select p from other_problems union all select p from row_problems)
select case when count(*) = 0 then 'SAFE TO RUN' else 'DO NOT RUN YET' end as verdict,
       current_setting('server_version')                                     as postgres,
       coalesce(string_agg(p, '; ' order by p), 'none')                      as problems
from all_problems;
