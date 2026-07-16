.PHONY: dev stop migrate seed test lint build test-backend test-mobile lint-backend lint-mobile build-backend build-mobile

dev:
	docker-compose -f infra/docker/docker-compose.yml up -d

stop:
	docker-compose -f infra/docker/docker-compose.yml down

migrate:
	cd backend && go run cmd/api/main.go --migrate

seed:
	bash infra/scripts/seed.sh

test-backend:
	cd backend && go test ./...

test-mobile:
	cd mobile && flutter test

lint-backend:
	cd backend && golangci-lint run

lint-mobile:
	cd mobile && flutter analyze

build-backend:
	docker build -t sayurpintar-api:latest backend/

build-mobile:
	cd mobile && flutter build apk --release

setup:
	bash infra/scripts/setup.sh

clean:
	docker-compose -f infra/docker/docker-compose.yml down -v
