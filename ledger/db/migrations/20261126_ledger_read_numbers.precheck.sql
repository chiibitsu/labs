-- Read-only pre-check for 20261126_ledger_read_numbers.sql. Run this FIRST.
-- It only reads the database's own catalogue (names and types). It changes nothing
-- and reads no ledger rows.
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
  select 'a function named ' || p.proname || ' already exists with a different shape'
  from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public'
    and (   (p.proname = 'ledger_read_numbers'      and pg_get_function_identity_arguments(p.oid) <> 'p_token text, p_limit integer, p_offset integer')
         or (p.proname = 'ledger_new_read_token'    and pg_get_function_identity_arguments(p.oid) <> 'p_label text')
         or (p.proname = 'ledger_revoke_read_token' and pg_get_function_identity_arguments(p.oid) <> 'p_label text'))
),
all_problems as (select p from col_problems union all select p from other_problems)
select case when count(*) = 0 then 'SAFE TO RUN' else 'DO NOT RUN YET' end as verdict,
       current_setting('server_version')                                     as postgres,
       coalesce(string_agg(p, '; ' order by p), 'none')                      as problems
from all_problems;
