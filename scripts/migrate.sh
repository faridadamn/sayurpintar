#!/usr/bin/env bash
set -Eeuo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"

MIGRATIONS_DIR="${MIGRATIONS_DIR:-backend/migrations}"
LOCK_ID="${MIGRATION_LOCK_ID:-741936821}"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run database migrations" >&2
  exit 127
fi

if [[ ! -d "$MIGRATIONS_DIR" ]]; then
  echo "Migration directory not found: $MIGRATIONS_DIR" >&2
  exit 1
fi

mapfile -t migration_files < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.up.sql' | sort)

if [[ ${#migration_files[@]} -eq 0 ]]; then
  echo "No migration files found in $MIGRATIONS_DIR" >&2
  exit 1
fi

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SELECT pg_advisory_lock(${LOCK_ID});
SQL

cleanup() {
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT pg_advisory_unlock(${LOCK_ID});" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for file in "${migration_files[@]}"; do
  version="$(basename "$file" .up.sql)"

  already_applied="$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 \
    -v version="$version" \
    -c "SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE version = :'version');")"

  if [[ "$already_applied" == "t" ]]; then
    echo "SKIP $version"
    continue
  fi

  echo "APPLY $version"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
BEGIN;
\i $file
INSERT INTO schema_migrations(version) VALUES ('$version');
COMMIT;
SQL

done

echo "All migrations applied successfully"
