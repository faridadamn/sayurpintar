#!/bin/bash
set -e

echo "Running database migrations..."

cd "$(dirname "$0")/../../backend"

go run cmd/api/main.go --migrate

echo "Migrations complete."
