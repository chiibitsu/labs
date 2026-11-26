#!/usr/bin/env bash
# Runs the read-door tests on a throwaway local Postgres. Never touches the real ledger.
#   bash ledger/db/test/run.sh
# Needs Postgres 13+ server binaries (initdb, pg_ctl). Set PGBIN if they aren't on PATH.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
mig="$here/../migrations/20261126_ledger_read_numbers.sql"
PGBIN="${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1)}"
export PATH="$PGBIN:$PATH"

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

echo "1. migration applies, twice, and leaves write tokens untouched"
before="$(fingerprint t)"
q -d t -f "$mig"
q -d t -f "$mig"
[ "$before" = "$(fingerprint t)" ] || { echo "FAIL: migration changed ledger_tokens or ledger_ingest"; exit 1; }
echo "ok   ledger_tokens rows, grants, policies and ledger_ingest are byte-for-byte unchanged"
q -d t -At -c "select count(*) from public.ledger_read_tokens" | grep -qx 0 \
  || { echo "FAIL: self-check left a token behind"; exit 1; }
echo "ok   self-check leaves no token behind"

echo "2. the door"
q -d t -f "$here/test_read_door.sql" 2>&1 | sed 's/^psql:[^ ]* NOTICE:  /  /; s/^NOTICE:  /  /'
[ "$before" = "$(fingerprint t)" ] || { echo "FAIL: tests changed ledger_tokens or ledger_ingest"; exit 1; }

echo "3. a misnamed ledger column makes the whole migration roll back"
q -c "create database bad"
q -d bad -f "$here/standin_schema.sql"
q -d bad -c "alter table public.ledger_sessions rename column cost_basis to cost_kind"
q -d bad -c "alter table public.ledger_sessions alter column model_usage type text"
out="$(precheck bad)"
case "$out" in "DO NOT RUN YET | "*"cost_basis is missing"*"model_usage is text"*) echo "ok   pre-check stops on a mismatched ledger: $out";;
  *) echo "FAIL: pre-check said: $out"; exit 1;; esac
if q -d bad -f "$mig" >/dev/null 2>&1; then echo "FAIL: migration applied on a mismatched ledger"; exit 1; fi
q -d bad -At -c "select to_regclass('public.ledger_read_tokens') is null and to_regproc('public.ledger_read_numbers') is null" | grep -qx t \
  || { echo "FAIL: a failed apply left something behind"; exit 1; }
echo "ok   apply refused and nothing was kept"

echo "all passed"
