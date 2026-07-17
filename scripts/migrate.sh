#!/usr/bin/env bash
set -Eeuo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"

MIGRATIONS_DIR="${MIGRATIONS_DIR:-backend/migrations}"
LOCK_ID="${MIGRATION_LOCK_ID:-741936821}"

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required to run database migrations" >&2
  exit 127
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "sha256sum is required to verify database migrations" >&2
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

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY,
  checksum text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);
SQL

for file in "${migration_files[@]}"; do
  version="$(basename "$file" .up.sql)"
  checksum="$(sha256sum "$file" | awk '{print $1}')"

  existing_checksum="$(psql "$DATABASE_URL" -At -v ON_ERROR_STOP=1 \
    -v version="$version" \
    -c "SELECT checksum FROM schema_migrations WHERE version = :'version';")"

  if [[ -n "$existing_checksum" ]]; then
    if [[ "$existing_checksum" != "$checksum" ]]; then
      echo "Checksum mismatch for applied migration $version" >&2
      exit 1
    fi
    echo "SKIP $version"
    continue
  fi

  echo "APPLY $version"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
    -v lock_id="$LOCK_ID" \
    -v version="$version" \
    -v checksum="$checksum" <<SQL
BEGIN;
SELECT pg_advisory_xact_lock(:lock_id);
\i $file
INSERT INTO schema_migrations(version, checksum)
VALUES (:'version', :'checksum');
COMMIT;
SQL
done

echo "All migrations applied successfully"
