#!/usr/bin/env bash
# Runs the read-door tests on a throwaway local Postgres. Never touches the real ledger.
#   bash ledger/db/test/run.sh
# Needs Postgres 13+ server binaries (initdb, pg_ctl). Set PGBIN if they aren't on PATH.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mig="$here/../migrations/20261126_ledger_read_numbers.sql"
if [ -n "${PGBIN:-}" ]; then export PATH="$PGBIN:$PATH"
elif ! command -v initdb >/dev/null 2>&1; then  # Debian/Ubuntu keep them off PATH
  PGBIN="$(for d in /usr/lib/postgresql/*/bin; do [ -x "$d/initdb" ] && echo "$d"; done | sort -V | tail -1 || true)"
  [ -n "$PGBIN" ] && export PATH="$PGBIN:$PATH"
fi
command -v initdb >/dev/null 2>&1 && command -v pg_ctl >/dev/null 2>&1 \
  || { echo "run.sh: Postgres server tools (initdb, pg_ctl) not found; install Postgres 13+ or set PGBIN"; exit 1; }

work="$(mktemp -d)"
as=""; if [ "$(id -u)" = 0 ]; then as="runuser -u postgres --"; chown postgres "$work"; fi
cleanup() { $as pg_ctl -D "$work/db" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

$as initdb -D "$work/db" -U postgres -A trust >/dev/null
$as pg_ctl -D "$work/db" -o "-k $work -c listen_addresses=''" -l "$work/log" -w start >/dev/null
q() { $as psql -h "$work" -U postgres -X -v ON_ERROR_STOP=1 -q "$@"; }

fingerprint() {  # everything about the existing write tokens and write door
  q -d "$1" -At -c "select md5(
      (select coalesce(string_agg(t::text, ',' order by id), '') from public.ledger_tokens t)
   || (select coalesce(relacl::text, '') from pg_class where oid = 'public.ledger_tokens'::regclass)
   || (select relrowsecurity::text from pg_class where oid = 'public.ledger_tokens'::regclass)
   || (select count(*)::text from pg_policies where tablename = 'ledger_tokens')
   || (select prosrc || coalesce(proacl::text, '') from pg_proc where oid = 'public.ledger_ingest(text,jsonb)'::regprocedure))"
}

pre="$here/../migrations/20261126_ledger_read_numbers.precheck.sql"
precheck() {  # run the pre-check in a read-only transaction: any write would error
  $as env PGOPTIONS="-c default_transaction_read_only=on" psql -h "$work" -U postgres -X -v ON_ERROR_STOP=1 -q -At -F ' | ' -d "$1" -f "$pre"
}

echo "0. read-only pre-check"
q -c "create database t"
q -d t -f "$here/standin_schema.sql"
out="$(precheck t)"
case "$out" in "SAFE TO RUN | "*"| none") echo "ok   matching ledger: $out";; *) echo "FAIL: pre-check said: $out"; exit 1;; esac

q -c "create database clash"
q -d clash -f "$here/standin_schema.sql"
q -d clash -c "create table public.ledger_read_tokens (id uuid, label text, token_hash text, revoked boolean, created_at timestamptz, owner text not null)"
out="$(precheck clash)"
case "$out" in "DO NOT RUN YET | "*"ledger_read_tokens already exists"*) echo "ok   pre-check stops on a clashing ledger_read_tokens table";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac

q -c "create database foreign_owner"
q -d foreign_owner -f "$here/standin_schema.sql"
q -d foreign_owner -c "create role intruder nologin" -c "create table public.ledger_read_tokens (id uuid primary key default gen_random_uuid(), label text not null, token_hash text not null unique, revoked boolean not null default false, created_at timestamptz not null default now())" -c "alter table public.ledger_read_tokens owner to intruder"
out="$(precheck foreign_owner)"
case "$out" in "DO NOT RUN YET | "*"owned by intruder"*) echo "ok   pre-check stops on a read-token table owned by another role";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac
if q -d foreign_owner -f "$mig" >/dev/null 2>&1; then echo "FAIL: migration ran on a foreign-owned token table"; exit 1; fi
q -d foreign_owner -At -c "select to_regproc('public.ledger_read_numbers') is null" | grep -qx t \
  || { echo "FAIL: door was created on a foreign-owned token table"; exit 1; }
echo "ok   migration refuses a foreign-owned token table and creates no door"

q -c "create database foreign_fn"
q -d foreign_fn -f "$here/standin_schema.sql"
q -d foreign_fn -c "create role intruder2 nologin" \
  -c "create function public.ledger_read_numbers(p_token text, p_limit integer default 500, p_offset integer default 0) returns setof integer language sql as 'select 1'" \
  -c "alter function public.ledger_read_numbers(text,integer,integer) owner to intruder2"
out="$(precheck foreign_fn)"
case "$out" in "DO NOT RUN YET | "*"ledger_read_numbers"*"owned by intruder2"*) echo "ok   pre-check stops on a door function owned by another role";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac
if q -d foreign_fn -f "$mig" >/dev/null 2>&1; then echo "FAIL: migration ran over a foreign-owned function"; exit 1; fi
q -d foreign_fn -At -c "select pg_get_userbyid(proowner) || ' ' || pg_get_function_result(oid) from pg_proc where proname = 'ledger_read_numbers'" | grep -qx "intruder2 SETOF integer" \
  && q -d foreign_fn -At -c "select to_regclass('public.ledger_read_tokens') is null" | grep -qx t \
  || { echo "FAIL: migration changed something on a foreign-owned function"; exit 1; }
echo "ok   migration refuses a foreign-owned function and changes nothing"
q -d foreign_fn -c "alter function public.ledger_read_numbers(text,integer,integer) owner to postgres"
out="$(precheck foreign_fn)"
case "$out" in "DO NOT RUN YET | "*"ledger_read_numbers"*"different shape"*) echo "ok   pre-check stops on a same-arguments function with a different return";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac

for case_ in policy grant; do
  q -c "create database pre_$case_"
  q -d pre_$case_ -f "$here/standin_schema.sql"
  q -d pre_$case_ -c "create table public.ledger_read_tokens (id uuid primary key default gen_random_uuid(), label text not null, token_hash text not null unique, revoked boolean not null default false, created_at timestamptz not null default now())" \
    -c "revoke all on public.ledger_read_tokens from anon, authenticated, service_role"
  if [ $case_ = policy ]; then
    q -d pre_$case_ -c "alter table public.ledger_read_tokens enable row level security" -c "create policy open_door on public.ledger_read_tokens for all using (true) with check (true)"
    want="row-level policies"
  else
    q -d pre_$case_ -c "create role api_custom nologin" -c "grant insert, select on public.ledger_read_tokens to api_custom"
    want="grants to api_custom"
  fi
  out="$(precheck pre_$case_)"
  case "$out" in "DO NOT RUN YET | "*"$want"*) echo "ok   pre-check stops on an existing token table with $want";;
    *) echo "FAIL: pre-check said: $out"; exit 1;; esac
  if q -d pre_$case_ -f "$mig" >/dev/null 2>&1; then echo "FAIL: migration ran over a token table with $want"; exit 1; fi
  q -d pre_$case_ -At -c "select to_regproc('public.ledger_read_numbers') is null" | grep -qx t \
    || { echo "FAIL: door created over a token table with $want"; exit 1; }
  echo "ok   migration refuses an existing token table with $want and creates no door"
done

q -c "create database prepop"
q -d prepop -f "$here/standin_schema.sql"
q -d prepop -c "create table public.ledger_read_tokens (id uuid primary key default gen_random_uuid(), label text not null, token_hash text not null unique, revoked boolean not null default false, created_at timestamptz not null default now())" \
  -c "revoke all on public.ledger_read_tokens from anon, authenticated, service_role" \
  -c "insert into public.ledger_read_tokens (label, token_hash) values ('planted', encode(sha256(convert_to('known', 'UTF8')), 'hex'))"
out="$(precheck prepop)"
case "$out" in "DO NOT RUN YET | "*"already holds 1 token"*) echo "ok   pre-check stops on a token table that already holds a token";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac

echo "1. migration applies, twice, and leaves write tokens untouched"
before="$(fingerprint t)"
q -d t -f "$mig"
q -d t -f "$mig"
[ "$before" = "$(fingerprint t)" ] || { echo "FAIL: migration changed ledger_tokens or ledger_ingest"; exit 1; }
echo "ok   ledger_tokens rows, grants, policies and ledger_ingest are byte-for-byte unchanged"
q -d t -At -c "select count(*) from public.ledger_read_tokens" | grep -qx 0 \
  || { echo "FAIL: self-check left a token behind"; exit 1; }
echo "ok   self-check leaves no token behind"
out="$(precheck t)"
case "$out" in "SAFE TO RUN | "*"| none") echo "ok   pre-check still says SAFE after the migration (re-run is fine)";;
  *) echo "FAIL: pre-check after migration said: $out"; exit 1;; esac

echo "2. the door"
q -d t -f "$here/test_read_door.sql" 2>&1 | sed 's/^psql:[^ ]* NOTICE:  /  /; s/^NOTICE:  /  /'
[ "$before" = "$(fingerprint t)" ] || { echo "FAIL: tests changed ledger_tokens or ledger_ingest"; exit 1; }

echo "2b. read-only token audit"
out="$($as env PGOPTIONS="-c default_transaction_read_only=on" psql -h "$work" -U postgres -X -v ON_ERROR_STOP=1 -q -At -F ' | ' -d t -f "$here/../checks/20261127_read_tokens_audit.sql")"
case "$out" in "nightly export | "*"| t | revoked") echo "ok   audit lists labels and status only: $(echo "$out" | sed 's/ | 20[^|]*|/ | <time> |/')";;
  *) echo "FAIL: audit said: $out"; exit 1;; esac
echo "$out" | grep -q '[0-9a-f]\{64\}' && { echo "FAIL: audit shows a fingerprint"; exit 1; }

echo "3. a misnamed ledger column makes the whole migration roll back"
q -c "create database bad"
q -d bad -f "$here/standin_schema.sql"
q -d bad -c "alter table public.ledger_sessions rename column cost_basis to cost_kind"
q -d bad -c "alter table public.ledger_sessions alter column model_usage type text"
q -d bad -c "alter table public.ledger_sessions alter column tokens_output type numeric"
out="$(precheck bad)"
case "$out" in "DO NOT RUN YET | "*"cost_basis is missing"*"model_usage is text"*"tokens_output is numeric"*) echo "ok   pre-check stops on a mismatched ledger: $out";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac
if q -d bad -f "$mig" >/dev/null 2>&1; then echo "FAIL: migration applied on a mismatched ledger"; exit 1; fi
q -d bad -At -c "select to_regclass('public.ledger_read_tokens') is null and to_regproc('public.ledger_read_numbers') is null" | grep -qx t \
  || { echo "FAIL: a failed apply left something behind"; exit 1; }
echo "ok   apply refused and nothing was kept"

echo "all passed"
