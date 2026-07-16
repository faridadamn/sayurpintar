#!/bin/bash
# Seed products data into PostgreSQL
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-sayurpintar}"
DB_USER="${POSTGRES_USER:-sp_dev}"

echo "Seeding products into $DB_NAME..."

PRODUCTS_FILE="$SCRIPT_DIR/products.json"

if [ ! -f "$PRODUCTS_FILE" ]; then
    echo "Error: products.json not found at $PRODUCTS_FILE"
    exit 1
fi

# Read JSON and generate INSERT statements
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
INSERT INTO products (name, category, default_unit) VALUES
$(cat "$PRODUCTS_FILE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
values = []
for p in data:
    name = p['name'].replace(\"'\", \"''\")
    cat = p['category'].replace(\"'\", \"''\")
    unit = p['default_unit'].replace(\"'\", \"''\")
    values.append(f\"('{name}', '{cat}', '{unit}')\")
print(',\n'.join(values))
")
ON CONFLICT DO NOTHING;
"

echo "Products seeded successfully."
