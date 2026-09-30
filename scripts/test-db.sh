#!/usr/bin/env bash
# Pokreće RLS testove baze.
#
#   scripts/test-db.sh                 # lokalni Supabase (supabase start), migracije već primenjene
#   DATABASE_URL=... scripts/test-db.sh
#
# Ako baza nema Supabase auth šemu (običan Postgres, npr. u CI-ju), skripta
# prvo primeni supabase/tests/support/supabase_stub.sql i sve migracije.
# Nikad ne pokretati sa DATABASE_URL-om produkcione baze: stub i migracije
# se primenjuju samo na praznu bazu, a sami testovi se uvek poništavaju.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
PSQL=(psql "$DATABASE_URL" --no-psqlrc -v ON_ERROR_STOP=1 -q)

has_auth=$("${PSQL[@]}" -tAc "select to_regclass('auth.users') is not null")
if [[ "$has_auth" != "t" ]]; then
  has_tables=$("${PSQL[@]}" -tAc "select count(*) from pg_tables where schemaname = 'public'")
  if [[ "$has_tables" != "0" ]]; then
    echo "Baza nema auth.users, a public šema nije prazna; odbijam da je menjam." >&2
    exit 1
  fi
  echo "→ Običan Postgres: primenjujem Supabase stub i migracije"
  "${PSQL[@]}" -f "$ROOT/supabase/tests/support/supabase_stub.sql"
  for f in "$ROOT"/supabase/migrations/*.sql; do
    echo "  $(basename "$f")"
    "${PSQL[@]}" -f "$f"
  done
fi

for t in "$ROOT"/supabase/tests/*.test.sql; do
  echo "→ $(basename "$t")"
  "${PSQL[@]}" -f "$t"
done
