# 🥬 SayurPintar

**Optimasi operasi harian untuk tukang sayur keliling**

SayurPintar adalah aplikasi mobile yang membantu pedagang sayur keliling mengoptimalkan operasi harian mereka. Aplikasi ini menggabungkan optimasi rute, manajemen langganan, dan benchmark harga real-time.

---

## 🏗️ Arsitektur

```
┌─────────────────────────────────────────────────┐
│                    Mobile App                    │
│               (Flutter + Riverpod)               │
├─────────────────────────────────────────────────┤
│                     REST API                     │
│              (Go + Fiber + pgx)                  │
├──────────┬──────────┬──────────┬────────────────┤
│PostgreSQL│  Redis   │ MongoDB  │  Meilisearch   │
│ +PostGIS │ (Cache)  │ (Logs)   │   (Search)     │
└──────────┴──────────┴──────────┴────────────────┘
```

## 🛠️ Tech Stack

### Backend
- **Language:** Go 1.22
- **Framework:** Fiber v2
- **Database:** PostgreSQL 15 + PostGIS
- **Cache:** Redis 7
- **Document Store:** MongoDB 7
- **Search:** Meilisearch v1.5
- **Auth:** JWT (OTP via WhatsApp/SMS)

### Mobile
- **Framework:** Flutter 3.19+
- **State Management:** Riverpod
- **Navigation:** GoRouter
- **Maps:** flutter_map + OpenStreetMap
- **Storage:** SQLite + Hive + SharedPreferences

### Infrastructure
- **Containers:** Docker + Docker Compose
- **Orchestration:** Kubernetes (K3s)
- **CI/CD:** GitHub Actions
- **Ingress:** NGINX Ingress + cert-manager

---

## 🚀 Quick Start

### Prerequisites
- Go 1.22+
- Flutter 3.19+
- Docker & Docker Compose
- Make (optional)

### 1. Clone & Setup
```bash
git clone https://github.com/sayurpintar/sayurpintar.git
cd sayurpintar
make setup
```

### 2. Start Services
```bash
# Start databases
make dev

# Start API server
cd backend && go run cmd/api/main.go

# Start mobile app (in another terminal)
cd mobile && flutter run
```

### 3. Environment
```bash
cp .env.example .env
# Edit .env with your settings
```

---

## 📁 Project Structure

```
sayurpintar/
├── backend/          # Go API server
│   ├── cmd/api/      # Entry point
│   ├── internal/     # Business logic
│   ├── migrations/   # SQL migrations
│   ├── seeds/        # Seed data
│   └── api/          # OpenAPI spec
├── mobile/           # Flutter app
│   ├── lib/app/      # App config
│   ├── lib/core/     # Shared utilities
│   ├── lib/features/ # Feature modules
│   └── lib/shared/   # Shared widgets
├── infra/            # Infrastructure
│   ├── docker/       # Docker Compose
│   ├── k8s/          # Kubernetes manifests
│   └── scripts/      # Dev scripts
├── .github/          # CI/CD pipelines
└── docs/             # Documentation
```

---

## 📝 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Liveness check |
| GET | `/ready` | Readiness check |
| POST | `/api/v1/auth/send-otp` | Send OTP |
| POST | `/api/v1/auth/verify-otp` | Verify OTP |
| GET | `/api/v1/profile` | Get profile |
| GET | `/api/v1/routes` | List routes |
| POST | `/api/v1/routes` | Create route |
| POST | `/api/v1/routes/:id/optimize` | Optimize route |
| GET | `/api/v1/subscriptions/packages` | List packages |
| POST | `/api/v1/subscriptions/subscribe` | Subscribe |
| GET | `/api/v1/prices` | Get prices |
| POST | `/api/v1/prices` | Submit price |
| GET | `/api/v1/orders` | List orders |
| GET | `/api/v1/transactions/summary` | P&L summary |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- **Go:** Follow standard Go conventions, use `golangci-lint`
- **Dart:** Follow Flutter linter rules, use `flutter analyze`
- **Commits:** Use conventional commits format

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
