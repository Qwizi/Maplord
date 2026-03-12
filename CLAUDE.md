# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MapLord 2.0** is a real-time strategy web game built on a world map. Players claim territories, build armies, and compete in real-time matches. The project uses CalVer versioning (e.g., `v2026.3.10.1`).

## Commands

### Backend (Python / Django)

Uses `uv` as the package manager and Python 3.13.

```bash
uv sync                                          # Install dependencies
uv run python manage.py runserver               # Dev server (port 8000)
uv run python manage.py migrate                 # Run migrations
uv run python manage.py makemigrations          # Create migrations
uv run celery -A config worker -l info          # Celery worker
uv run celery -A config beat -l info            # Celery beat scheduler
```

### Rust Gateway

Cargo workspace under `gateway/`. Requires Rust 1.88+.

```bash
cd gateway
cargo build                    # Build all crates
cargo test                     # Run all tests
cargo run --bin maplord-gateway  # Run the gateway server (port 8080)
```

### Frontend (Next.js)

Uses `pnpm` as the package manager. Run from the `frontend/` directory.

```bash
pnpm dev      # Dev server on port 3000
pnpm build    # Production build
pnpm lint     # ESLint
```

### Docker Compose (recommended for full-stack dev)

```bash
docker compose up          # Start all services (db, redis, backend, celery, celery-beat, frontend, gateway, caddy)
docker compose up backend  # Start specific service
```

Ports in dev: Caddy on 80, backend on 8002, frontend on 3002, gateway on 8080, PostgreSQL on 5433, Redis on 6380.

## Architecture

### Backend (Django)

Six Django apps under `apps/`:

- **accounts** — User model, JWT auth, profiles
- **geo** — Geospatial data (Country, Region) using PostGIS
- **game_config** — Admin-configurable game settings (building/unit types, costs)
- **matchmaking** — Match queue and player pairing; creates Match objects; internal API for Rust gateway
- **game** — Match models, snapshots, internal API for Rust gateway; Celery tasks (ELO, cleanup)
- **shop** — Shop items and categories (placeholder)

Key config under `config/`:
- `asgi.py` — ASGI entry point (HTTP only, WebSocket handled by Rust gateway)
- `celery.py` — Celery app config
- `settings.py` — Main settings using `python-decouple` for env vars

### Rust Gateway (`gateway/`)

Cargo workspace with 5 crates handling all WebSocket traffic:

- **maplord-gateway** — Binary: axum WS server, JWT auth, routing, game consumer
- **maplord-engine** — Lib: pure game logic (tick processing, combat, economy, pathfinding)
- **maplord-state** — Lib: Redis state management with msgpack (rmp-serde)
- **maplord-matchmaking** — Lib: matchmaking queue logic with DashMap connection groups
- **maplord-django** — Lib: Django internal API client (reqwest)

### Real-time Game Flow

```
Client ↔ WebSocket ↔ Rust Gateway (auth, matchmaking, game loop, engine)
                           ↓
                     Redis (live state, msgpack)
                           ↓
              Django HTTP Internal API (match creation, snapshots, ELO)
              Celery (async cleanup, stale match handling)
```

Game state is stored in Redis (via msgpack/rmp-serde serialization) during active matches; Celery periodically snapshots state to PostgreSQL and runs post-match ELO calculations. The Rust gateway communicates with Django via internal HTTP API (`/api/internal/`) secured by `X-Internal-Secret` header.

### Frontend

Next.js 16 App Router with TypeScript:

- `app/` — Pages (App Router)
- `components/` — React components (ui, map, game, auth)
- `lib/api.ts` — REST API client
- `lib/ws.ts` — WebSocket client
- `hooks/` — Custom React hooks

Key libraries: MapLibre GL (map rendering), shadcn/ui + Tailwind CSS 4 (UI), React Hook Form + Zod (form validation), Sonner (toasts).

### Infrastructure

- **Caddy** — Reverse proxy, routes `/api/` to backend, `/ws/` to Rust gateway, serves static/media files
- **PostgreSQL 16 + PostGIS** — Spatial game data, match history, player records
- **Redis 7** — Real-time game state cache, matchmaking queue
- **Celery + Redis** — Background tasks (ELO, snapshots, cleanup)

## Key Conventions

- **API layer**: Django Ninja Extra (FastAPI-style, Pydantic schemas, auto OpenAPI docs at `/api/docs`)
- **Auth**: JWT via `django-ninja-jwt` (HS256, same SECRET_KEY shared with Rust gateway)
- **Schemas**: Pydantic v2 (input/output schemas colocated with each app)
- **WebSocket messages**: JSON over WebSocket (client ↔ gateway), msgpack in Redis (gateway ↔ Redis)
- **Spatial queries**: PostGIS via `django.contrib.gis`
- **Internal API**: `/api/internal/` endpoints secured by `X-Internal-Secret` header for Rust gateway → Django communication
