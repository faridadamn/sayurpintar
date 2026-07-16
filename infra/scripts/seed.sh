#!/bin/bash
set -e

echo "Seeding database..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source .env if it exists
if [ -f "$SCRIPT_DIR/../../.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/../../.env" | xargs)
fi

bash "$SCRIPT_DIR/../../backend/seeds/seed.sh"

echo "Seed complete."
