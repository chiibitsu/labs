-- Tests for 20261126_ledger_read_numbers.sql. Run by run.sh against the stand-in.
-- Every check raises on failure; psql runs with ON_ERROR_STOP, so one failure stops the run.
\set ON_ERROR_STOP on
\set QUIET on
\o /dev/null

-- Mint a read token the way Chii will (SQL editor = superuser), keep it in a session setting.
select public.ledger_new_read_token('nightly export') as tok \gset
select set_config('t.tok', :'tok', false);

-- Helper: expect a call (run as anon, like the API) to fail with a given error code.
create function pg_temp.expect_error(p_sql text, p_code text, p_what text) returns void language plpgsql as $$
begin
  execute p_sql;
  raise exception 'FAIL: % (expected error %, got success)', p_what, p_code;
exception when others then
  if sqlstate <> p_code then
    raise exception 'FAIL: % (expected error %, got % %)', p_what, p_code, sqlstate, sqlerrm;
  end if;
  raise notice 'ok   %', p_what;
end $$;
grant execute on function pg_temp.expect_error(text, text, text) to anon;

create function pg_temp.ok(p_cond boolean, p_what text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'FAIL: %', p_what; end if;
  raise notice 'ok   %', p_what;
end $$;
grant execute on function pg_temp.ok(boolean, text) to anon;

-- ── Shape: the door returns exactly the allowlist ────────────────────────────
select pg_temp.ok(
  (select array_agg(p.parameter_name::text order by p.ordinal_position)
     from information_schema.parameters p
     join information_schema.routines r using (specific_schema, specific_name)
    where r.routine_schema = 'public' and r.routine_name = 'ledger_read_numbers' and p.parameter_mode = 'OUT')
  = array['started_at','ended_at','source','project','ai_minutes','you_minutes','human_minutes','saved_minutes',
          'cost_usd','cost_basis','tokens_input','tokens_cache_read','tokens_output','model_usage'],
  'door declares exactly the 14 allowlisted columns');

select pg_temp.ok(
  (select provolatile = 's' and prosecdef and proconfig @> array['search_path=""']
     from pg_proc where oid = 'public.ledger_read_numbers(text,integer,integer)'::regprocedure),
  'door is STABLE (Postgres refuses writes inside it), security definer, empty search_path');

select pg_temp.ok(
  (select prosrc !~* '\m(insert|update|delete|truncate|merge|copy|grant|alter|create|drop|execute)\M'
     from pg_proc where oid = 'public.ledger_read_numbers(text,integer,integer)'::regprocedure),
  'door body has no write, DDL or dynamic-SQL statement');

-- ── From here on, act as the API caller holding only the publishable key ─────
set role anon;

select pg_temp.ok((select count(*) = 500 from public.ledger_read_numbers(current_setting('t.tok'))),
  'valid read token: default page is 500 rows');
select pg_temp.ok((select count(*) = 1000 from public.ledger_read_numbers(current_setting('t.tok'), 5000, 0)),
  'page size is capped at 1000');
select pg_temp.ok((select count(*) = 200 from public.ledger_read_numbers(current_setting('t.tok'), 1000, 1000)),
  'second page returns the remaining 200');
select pg_temp.ok(
  (select count(*) = 1200 and count(distinct started_at) = 1200
     from (select * from public.ledger_read_numbers(current_setting('t.tok'), 1000, 0)
           union all
           select * from public.ledger_read_numbers(current_setting('t.tok'), 1000, 1000)) x),
  'paging covers every session exactly once');
select pg_temp.ok(
  (select sum(cost_usd) = (1.25 * 1200 * 1201 / 2)::numeric
     from (select * from public.ledger_read_numbers(current_setting('t.tok'), 1000, 0)
           union all
           select * from public.ledger_read_numbers(current_setting('t.tok'), 1000, 1000)) x),
  'cost numbers come through unchanged');

select pg_temp.ok(
  (select count(*) = 0 from (
     select row_to_json(r)::text j from public.ledger_read_numbers(current_setting('t.tok'), 1000, 0) r
     union all
     select row_to_json(r)::text from public.ledger_read_numbers(current_setting('t.tok'), 1000, 1000) r) x
   where j like '%FREETEXT%'),
  'no free text (titles, estimate basis, action log, keep list) in any row');

select pg_temp.ok(
  (select model_usage = '{"claude-opus-5-5": {"inputTokens": 7, "priced": true}}'::jsonb
     from public.ledger_read_numbers(current_setting('t.tok'), 1, 0)),
  'model_usage keeps model names with their numbers and true/false fields, drops text');
select pg_temp.ok(
  (select model_usage is null from public.ledger_read_numbers(current_setting('t.tok'), 1, 1199)),
  'a model_usage that is not an object comes back empty, not as-is');

-- ── A column added later must not leak ───────────────────────────────────────
reset role;
alter table public.ledger_sessions add column secret_note text default 'FREETEXT-NEW-COLUMN';
set role anon;
select pg_temp.ok(
  (select count(*) = 0 from public.ledger_read_numbers(current_setting('t.tok'), 1000, 0) r
    where row_to_json(r)::text like '%FREETEXT%'),
  'a column added to ledger_sessions later is not returned');
select pg_temp.ok(
  (select array_agg(k order by k) from json_object_keys(
     (select row_to_json(r) from public.ledger_read_numbers(current_setting('t.tok'), 1, 0) r)) k)
  = array['ai_minutes','cost_basis','cost_usd','ended_at','human_minutes','model_usage','project','saved_minutes',
          'source','started_at','tokens_cache_read','tokens_input','tokens_output','you_minutes'],
  'a returned row has exactly the 14 allowlisted keys');

-- ── Wrong keys are refused (403 through the API) ─────────────────────────────
select pg_temp.expect_error($q$select * from public.ledger_read_numbers(null)$q$, '28000', 'no token is refused');
select pg_temp.expect_error($q$select * from public.ledger_read_numbers('')$q$, '28000', 'empty token is refused');
select pg_temp.expect_error($q$select * from public.ledger_read_numbers('ldr_guess')$q$, '28000', 'made-up token is refused');
select pg_temp.expect_error($q$select * from public.ledger_read_numbers('intake-token-test')$q$, '28000',
  'a write (intake) token cannot open the read door');

-- ── The read token cannot write ──────────────────────────────────────────────
select pg_temp.expect_error(format($q$select public.ledger_ingest(%L, '{"source":"x","title":"y"}')$q$, current_setting('t.tok')),
  '28000', 'read token is refused by the write door (ledger_ingest stand-in)');
select pg_temp.expect_error($q$select * from public.ledger_read_tokens$q$, '42501', 'API cannot read the read-token table');
select pg_temp.expect_error($q$insert into public.ledger_read_tokens (label, token_hash) values ('x','y')$q$, '42501',
  'API cannot add a read token');
select pg_temp.expect_error($q$update public.ledger_read_tokens set revoked = false$q$, '42501', 'API cannot un-revoke a read token');
select pg_temp.expect_error($q$delete from public.ledger_read_tokens$q$, '42501', 'API cannot delete read tokens');
select pg_temp.expect_error($q$select public.ledger_new_read_token('x')$q$, '42501', 'API cannot mint a read token');
select pg_temp.expect_error($q$select public.ledger_revoke_read_token('nightly export')$q$, '42501', 'API cannot revoke a read token');
select pg_temp.ok(not has_function_privilege('authenticated', 'public.ledger_read_numbers(text,integer,integer)', 'execute'),
  'signed-in page users are not granted the door (it is for scripts only)');

-- ── Revoking the read token shuts the door and leaves write tokens working ───
reset role;
select pg_temp.ok(public.ledger_revoke_read_token('nightly export') = 1, 'revoke by label revokes one token');
set role anon;
select pg_temp.expect_error(format($q$select * from public.ledger_read_numbers(%L)$q$, current_setting('t.tok')), '28000',
  'a revoked read token is refused');
select pg_temp.ok(public.ledger_ingest('intake-token-test', '{"source":"claude-code","title":"after revoke"}') is not null,
  'intake (write) token still works after the read token is revoked');
reset role;

\echo 'all read-door tests passed'
