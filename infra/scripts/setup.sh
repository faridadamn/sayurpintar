#!/bin/bash
set -e

echo "====================================="
echo "  SayurPintar - Development Setup"
echo "====================================="
echo ""

# Check prerequisites
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    fi
    echo "✅ $1 found: $(command -v "$1")"
}

echo "Checking prerequisites..."
check_command go
check_command flutter
check_command docker
check_command docker-compose

echo ""
echo "Checking Go version..."
go version

echo ""
echo "Checking Flutter version..."
flutter --version 2>/dev/null | head -2

echo ""
echo "Setting up environment..."
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✅ .env created from .env.example"
else
    echo "✅ .env already exists"
fi

echo ""
echo "Starting Docker Compose..."
docker-compose -f infra/docker/docker-compose.yml up -d

echo ""
echo "Waiting for services to be ready..."
sleep 10

echo ""
echo "Running migrations..."
cd backend
go mod download
go run cmd/api/main.go --migrate || echo "⚠️  Migrations skipped (manual run needed)"
cd ..

echo ""
echo "Seeding data..."
bash infra/scripts/seed.sh || echo "⚠️  Seed skipped (manual run needed)"

echo ""
echo "====================================="
echo "  ✅ Setup complete!"
echo "====================================="
echo ""
echo "Services running:"
echo "  PostgreSQL: localhost:5432"
echo "  Redis:      localhost:6379"
echo "  MongoDB:    localhost:27017"
echo "  Meilisearch: localhost:7700"
echo ""
echo "Run 'make dev' to start Docker services"
echo "Run 'cd backend && go run cmd/api/main.go' to start API"
echo "Run 'cd mobile && flutter run' to start mobile app"
