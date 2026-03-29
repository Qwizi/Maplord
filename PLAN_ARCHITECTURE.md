# Zelqor — Architecture Evolution Plan

Document created: 2026-03-29
Purpose: Implementation plan for architectural gaps, community servers, and plugin system.

---

## Executive Summary

5 phases, ~16-20 weeks. Each phase builds on the prior one. Community servers authenticate via the existing OAuth2/Developer system. Plugin registry integrates into the developer portal.

---

## Phase 1: Infrastructure Resilience (Weeks 1-3)

### 1A. Circuit Breaker + Retry in DjangoClient

**File:** `gateway/crates/zelqor-django/src/lib.rs`

Current `get()`, `post()`, `patch()` methods use raw `reqwest` with zero resilience.

**Implementation:**
- Add `CircuitBreaker` struct with state (closed/half-open/open), failure count, last failure time
- Use `tokio::sync::RwLock<CircuitState>` for lock-free reads in happy path
- Wrap each HTTP call: check circuit -> execute with timeout (5s) -> retry with exponential backoff (max 3) -> update circuit state
- Add `DjangoError::CircuitOpen` variant
- Classify: 5xx + network errors trip circuit; 4xx do not

**Config additions** to `AppConfig`:
- `DJANGO_REQUEST_TIMEOUT_MS` (default 5000)
- `DJANGO_RETRY_COUNT` (default 3)
- `CIRCUIT_BREAKER_FAILURE_THRESHOLD` (default 5)
- `CIRCUIT_BREAKER_RESET_TIMEOUT_SECS` (default 30)

**Effort:** 3-4 days

### 1B. Graceful Shutdown

**File:** `gateway/crates/zelqor-gateway/src/main.rs`

Currently `axum::serve(listener, app).await` with no shutdown handling.

**Implementation:**
- Use `axum::serve(...).with_graceful_shutdown(shutdown_signal()).await`
- `shutdown_signal()` listens for SIGTERM + Ctrl+C
- On signal: set `AtomicBool` in `AppState`, stop new connections, send `server_shutting_down` to all clients, wait 30s for in-flight ticks, clean Redis locks

**Effort:** 2 days

### 1C. Secret Rotation -- Replace X-Internal-Secret

**Files:** `apps/internal_auth.py`, `gateway/crates/zelqor-django/src/lib.rs`

Switch to HMAC-based request signing:
```
X-Internal-Signature: ts=<unix_epoch>,sig=<HMAC-SHA256(secret, ts+method+path+body_hash)>
```
- Django: verify signature, reject if timestamp drift > 30s, support two active secrets for zero-downtime rotation
- Rust: compute HMAC using `hmac` + `sha2` crates

**Effort:** 2-3 days

### 1D. Dead Letter Queue for Celery

**Files:** `config/celery.py`, `config/settings.py`, new `apps/game/dlq.py`

- `task_reject_on_worker_lost = True`, `task_acks_late = True`
- `task_failure` signal handler -> `FailedTask` model
- Periodic `retry_dead_letter_tasks` Celery beat task
- Admin view for manual retry/resolution

**Model:**
```python
class FailedTask(models.Model):
    id = UUIDField(primary_key=True)
    task_name = CharField(max_length=255)
    task_id = CharField(max_length=255, unique=True)
    args = JSONField(default=list)
    kwargs = JSONField(default=dict)
    exception_type = CharField(max_length=255)
    exception_message = TextField()
    traceback = TextField()
    created_at = DateTimeField(auto_now_add=True)
    retry_count = IntegerField(default=0)
    resolved = BooleanField(default=False)
```

**Effort:** 2-3 days

---

## Phase 2: Event Bus (Weeks 3-5)

### 2A. Outbox Pattern -- Decompose finalize_match_results_sync()

**Problem:** `apps/game/tasks.py` `finalize_match_results_sync()` touches 7+ tables in one monolithic call (Match, MatchResult, GameStateSnapshot, PlayerResult, User ELO, User XP, ItemInstance StatTrak, inventory drops, notifications, webhooks, clan wars).

**Solution:**
- `OutboxEvent` model: aggregate_type, aggregate_id, event_type, payload, published flag
- **Core transaction** (atomic): Match status + MatchResult + PlayerResult + ELO + XP -> write OutboxEvents for side effects
- **Outbox publisher** (Celery beat every 1s): reads unpublished events -> Redis pub/sub -> marks published
- **Event handlers** (separate Celery tasks):
  - `handle_match_finalized` -> StatTrak, match drops
  - `handle_elo_changed` -> webhook dispatch
  - `handle_match_finished` -> notifications, clan war resolution

**Model:**
```python
class OutboxEvent(models.Model):
    id = UUIDField(primary_key=True)
    aggregate_type = CharField(max_length=50)   # "match"
    aggregate_id = CharField(max_length=100)    # match_id
    event_type = CharField(max_length=100)      # "match.finalized", "elo.updated"
    payload = JSONField()
    created_at = DateTimeField(auto_now_add=True)
    published = BooleanField(default=False)
    published_at = DateTimeField(null=True)
```

**Effort:** 5-7 days

---

## Phase 3: Gateway Split -- Central Gateway + Gamenode (Weeks 5-9)

### 3A. New Crate: `zelqor-gamenode`

Extract game engine execution into standalone binary.

**Gamenode owns:** game engine, Redis state, bot AI, anticheat
**Gateway retains:** player WebSocket, matchmaking, chat, social, voice, auth, server registry

```
gateway/crates/
+-- zelqor-gateway      # Central: auth, routing, registry, matchmaking
+-- zelqor-gamenode     # NEW: lightweight game server
+-- zelqor-protocol     # NEW: shared gateway<->gamenode messages
+-- zelqor-plugins      # NEW (Phase 5): WASM plugin runtime
+-- zelqor-engine       # Game logic (used by gamenode)
+-- zelqor-state        # Redis state (used by gamenode)
+-- zelqor-ai           # Bots (used by gamenode)
+-- zelqor-anticheat    # Anticheat (used by gamenode)
+-- zelqor-matchmaking  # Stays in gateway
+-- zelqor-django       # Stays in gateway
```

### 3B. New Crate: `zelqor-protocol`

Shared message types for gateway<->gamenode WebSocket communication:

```rust
pub enum GatewayToNode {
    PlayerAction { match_id: String, user_id: String, action: Action },
    PlayerConnect { match_id: String, user_id: String },
    PlayerDisconnect { match_id: String, user_id: String },
    StartMatch { match_id: String, match_data: MatchData },
    Heartbeat,
}

pub enum NodeToGateway {
    TickBroadcast { match_id: String, tick_data: TickBroadcastData },
    MatchFinished { match_id: String, winner_id: Option<String>, total_ticks: u64, final_state: Value },
    PlayerEliminated { match_id: String, user_id: String },
    HeartbeatAck { active_matches: u32, cpu_load: f32 },
}
```

### 3C. Server Auth via Existing OAuth2

**KEY INTEGRATION: Community servers authenticate using the existing `apps/developers/` OAuth system.**

**Django additions:**

1. New scope: `"server:connect"` in `VALID_SCOPES`
2. New grant type: `client_credentials` in `OAuthController.token()` -- standard OAuth2 machine-to-machine flow

```python
def _grant_client_credentials(self, payload):
    app = _verify_client(payload.client_id, payload.client_secret)
    if app is None:
        raise HttpError(401, "Invalid client credentials.")
    token = OAuthAccessToken.objects.create(
        app=app, user=app.owner,
        scopes=["server:connect"],
    )
    return OAuthTokenResponseSchema(...)
```

3. New model: `CommunityServer`

```python
class CommunityServer(models.Model):
    id = UUIDField(primary_key=True)
    app = ForeignKey(DeveloperApp, on_delete=CASCADE, related_name="servers")
    name = CharField(max_length=100)
    description = TextField(blank=True)
    region = CharField(max_length=50)       # us-east, eu-west
    max_players = PositiveIntegerField(default=100)
    is_public = BooleanField(default=True)  # listed in server browser
    status = CharField(choices=[
        ("online", "Online"),
        ("offline", "Offline"),
        ("maintenance", "Maintenance"),
    ])
    last_heartbeat = DateTimeField(null=True)
    custom_config = JSONField(default=dict)
    allowed_plugins = JSONField(default=list)
    is_verified = BooleanField(default=False)   # staff-verified for ranked
    created_at = DateTimeField(auto_now_add=True)
```

4. New API endpoints:
   - `POST /developers/apps/{app_id}/servers/` -- register server
   - `GET /developers/apps/{app_id}/servers/` -- list servers
   - `PATCH /developers/apps/{app_id}/servers/{id}/` -- update config
   - `DELETE /developers/apps/{app_id}/servers/{id}/` -- deregister
   - `GET /api/v1/servers/` -- public server browser
   - `GET /api/v1/servers/{id}/` -- server detail

5. New webhook events: `server.online`, `server.offline`, `server.match_started`, `server.match_finished`, `server.player_joined`

**Authentication flow:**
1. Developer registers app in developer portal (existing)
2. Gets OAuth `client_id` / `client_secret` (existing)
3. Gamenode calls `POST /oauth/token/` with `grant_type=client_credentials`
4. Receives `access_token` with `server:connect` scope
5. Gamenode opens WebSocket: `wss://gateway/ws/server/?token=<access_token>`
6. Gateway validates token, adds gamenode to ServerRegistry

### 3D. Gateway Server Registry

**New file:** `gateway/crates/zelqor-gateway/src/server_registry.rs`

```rust
pub struct ServerRegistry {
    servers: DashMap<String, ConnectedServer>,
}

pub struct ConnectedServer {
    server_id: String,
    app_id: String,
    ws_sender: mpsc::Sender<GatewayToNode>,
    active_matches: u32,
    max_matches: u32,
    region: String,
    last_heartbeat: Instant,
    is_official: bool,
}
```

**Official server = also a gamenode.** Same code path, no special cases.

### 3E. Player Routing

1. Match created -> gateway selects gamenode (by region, load, official/community preference)
2. Gateway sends `StartMatch` to selected gamenode via WebSocket
3. Gamenode initializes game state in its local Redis
4. Players connect to `/ws/game/{match_id}/` -> gateway forwards actions to gamenode, relays tick broadcasts back
5. Match ends -> gamenode sends `MatchFinished` to gateway -> gateway calls Django (ELO, drops via outbox)

**Effort:** 12-15 days

---

## Phase 4: Community Server Management + Frontend (Weeks 9-12)

### 4A. Developer Portal Frontend

New pages:
- `/developers/servers` -- manage community servers
- `/developers/servers/new` -- register new server (name, region, config)
- `/developers/servers/[id]` -- server config, status, player count, logs

### 4B. Public Server Browser

New page: `/servers`
- List public online servers with: name, region, player count, mode, ping
- Filters: region, game mode, player count, verified status
- Join button -> routes through gateway

### 4C. Custom Game Config

Community servers can override a subset of settings:
- Tick rate
- Max players per match
- Resource generation rates
- Unit/building availability
- Map pool

Validated against an allowlist. Merged with base config from `/api/v1/public/config/`.

### 4D. Anti-Abuse

- Community matches marked `is_community = True`, excluded from ranked ELO by default
- Server owners can request "ranked" status (staff-verified `is_verified` flag)
- Auto-revoke tokens after 72h without heartbeat
- Per-server metrics: player count, average match duration, cheat detections

### 4E. Gamenode Configuration

**New file:** `gateway/crates/zelqor-gamenode/src/config.rs`

Gamenode binary reads:
- `CLIENT_ID`, `CLIENT_SECRET` -- OAuth credentials
- `GATEWAY_URL` -- central gateway WebSocket URL
- `REDIS_URL` -- local Redis for game state
- `SERVER_NAME`, `REGION`, `MAX_PLAYERS` -- server metadata

On startup:
1. Authenticate via `client_credentials` grant
2. Connect to gateway WebSocket
3. Send registration with server metadata
4. Begin accepting matches from gateway

**Effort:** 8-10 days

---

## Phase 5: Plugin System -- WASM (Weeks 12-18)

### 5A. WASM Runtime

**New crate:** `gateway/crates/zelqor-plugins/`

**Technology:** wasmtime + WIT (WebAssembly Interface Types)

**WIT contract** (`zelqor-plugins/wit/plugin.wit`):
```wit
package zelqor:plugin@0.1.0;

interface game-hooks {
    record tick-context {
        tick: u64,
        player-count: u32,
        match-id: string,
    }
    record combat-event {
        attacker-region: string,
        defender-region: string,
        attacker-units: u32,
        defender-units: u32,
    }
    record player-action {
        user-id: string,
        action-type: string,
        payload: string,
    }

    on-tick: func(ctx: tick-context) -> list<string>;
    on-combat: func(event: combat-event) -> option<combat-event>;
    on-player-action: func(action: player-action) -> bool;
    on-match-start: func(match-id: string, player-ids: list<string>);
    on-match-end: func(match-id: string, winner-id: option<string>);
}

interface plugin-api {
    log: func(level: string, message: string);
    get-region-data: func(region-id: string) -> string;
    get-player-data: func(user-id: string) -> string;
    send-event: func(event-type: string, payload: string);
    get-config: func(key: string) -> option<string>;
}

world zelqor-plugin {
    import plugin-api;
    export game-hooks;
}
```

### 5B. Sandbox Limits (per plugin)

| Limit | Value |
|-------|-------|
| Memory | 16MB heap max (`wasmtime::ResourceLimiter`) |
| CPU | 1M fuel per tick call (`consume_fuel`) |
| Wall clock | 50ms timeout per hook call |
| Host calls | 1000 per tick |
| KV storage | 1MB per plugin |
| Network/FS | Blocked (no WASI) |
| Isolation | Separate `wasmtime::Store` per plugin |

### 5C. Plugin Registry (Developer Portal)

```python
class Plugin(models.Model):
    id = UUIDField(primary_key=True)
    app = ForeignKey(DeveloperApp, on_delete=CASCADE, related_name="plugins")
    name = CharField(max_length=100)
    slug = SlugField(unique=True)
    description = TextField(blank=True)
    version = CharField(max_length=50)
    wasm_blob = FileField(upload_to="plugins/")
    wasm_hash = CharField(max_length=128)   # SHA-256
    hooks = JSONField(default=list)         # ["on_tick", "on_combat", ...]
    is_published = BooleanField(default=False)
    is_approved = BooleanField(default=False)  # staff review required
    download_count = PositiveIntegerField(default=0)
    created_at = DateTimeField(auto_now_add=True)
    updated_at = DateTimeField(auto_now=True)

class PluginVersion(models.Model):
    id = UUIDField(primary_key=True)
    plugin = ForeignKey(Plugin, on_delete=CASCADE, related_name="versions")
    version = CharField(max_length=50)
    wasm_blob = FileField(upload_to="plugins/versions/")
    wasm_hash = CharField(max_length=128)
    changelog = TextField(blank=True)
    created_at = DateTimeField(auto_now_add=True)
```

New scope: `"plugins:manage"`

**API endpoints:**
- `POST /developers/apps/{app_id}/plugins/` -- upload plugin WASM
- `GET /developers/apps/{app_id}/plugins/` -- list my plugins
- `PATCH /developers/apps/{app_id}/plugins/{slug}/` -- update metadata
- `POST /developers/apps/{app_id}/plugins/{slug}/publish/` -- submit for review
- `GET /api/v1/plugins/` -- public plugin browser
- `GET /api/v1/plugins/{slug}/` -- plugin detail
- `GET /api/v1/plugins/{slug}/download/` -- download WASM blob

### 5D. Plugin SDKs

- **Rust:** `zelqor-plugin-sdk` crate -- wraps WIT bindings, typed helpers
- **Python:** via `componentize-py` -- decorator-based hook registration
- **TypeScript:** via `jco`/`ComponentizeJS` -- npm package `@zelqor/plugin-sdk`

### 5E. Hook Execution in Game Loop

```
Engine tick start
  1. Engine processes player actions
  2. on_player_action() -> plugins can Allow/Deny
  3. Engine resolves combat
  4. on_combat() -> plugins can modify combat result
  5. Engine calculates income
  6. on_tick() -> plugins run custom logic
  7. Engine finalizes state
Engine tick end -> broadcast state to clients
```

### 5F. Plugin Loading in Gamenode

On gamenode startup:
1. Read `allowed_plugins` from `CommunityServer` config
2. Download WASM blobs from Django (`GET /api/v1/plugins/{slug}/download/`)
3. Validate SHA-256 hash
4. Pre-compile with `wasmtime::Module::new()` (cached)
5. For each match, instantiate plugin instances in sandboxed stores
6. Call hooks at appropriate points in game loop

### 5G. Plugin Frontend

New pages:
- `/developers/plugins` -- manage my plugins
- `/developers/plugins/new` -- upload new plugin
- `/developers/plugins/[slug]` -- edit, versions, stats
- `/plugins` -- public plugin browser (search, filter by hooks, verified)
- `/plugins/[slug]` -- plugin detail page (description, versions, download count, install to server)

### 5H. Example Plugins

| Plugin | Description | Hooks |
|--------|-------------|-------|
| **Zombie Mode** | Random player becomes zombie, infected regions auto-spawn units | on_match_start, on_tick, on_region_capture |
| **Battle Royale** | Map shrinks every 60s, edge regions eliminated | on_tick |
| **Economy Tweaks** | Comeback mechanics (double income for weakest player) | on_tick |
| **Kill Streak** | CS-style kill streak messages | on_combat |

**Effort:** 15-20 days

---

## Dependency Graph

```
Phase 1 (Resilience) -----> Phase 2 (Event Bus)
        |
        +-----------------> Phase 3 (Gateway Split)
                                  |
                            Phase 4 (Community Mgmt + Frontend)
                                  |
                            Phase 5 (Plugins)
```

- Phase 1 and 2 can partially overlap
- Phase 3 requires Phase 1 (circuit breaker + graceful shutdown needed before distributed gamenodes)
- Phase 4 requires Phase 3 (community frontend needs gamenode + server registry)
- Phase 5 requires Phase 3 (plugins run inside gamenodes)

---

## Files Summary

### Phase 1 (Resilience)

| Action | File |
|--------|------|
| Modify | `gateway/crates/zelqor-django/src/lib.rs` -- circuit breaker, retry, HMAC signing |
| Modify | `gateway/crates/zelqor-gateway/src/config.rs` -- new config fields |
| Modify | `gateway/crates/zelqor-gateway/src/main.rs` -- graceful shutdown |
| Modify | `gateway/crates/zelqor-gateway/src/state.rs` -- shutdown flag |
| Modify | `apps/internal_auth.py` -- HMAC verification |
| Modify | `config/celery.py` -- DLQ configuration |
| Modify | `config/settings.py` -- Celery settings |
| Create | `apps/game/dlq.py` -- FailedTask model + signal handlers |

### Phase 2 (Event Bus)

| Action | File |
|--------|------|
| Create | `apps/game/outbox.py` -- OutboxEvent model + publisher |
| Modify | `apps/game/models.py` -- OutboxEvent model |
| Modify | `apps/game/tasks.py` -- refactor finalize_match_results_sync |

### Phase 3 (Gateway Split)

| Action | File |
|--------|------|
| Create | `gateway/crates/zelqor-gamenode/` -- new binary crate |
| Create | `gateway/crates/zelqor-protocol/` -- shared message types |
| Create | `gateway/crates/zelqor-gateway/src/server_registry.rs` |
| Create | `gateway/crates/zelqor-gateway/src/server_ws.rs` -- server WebSocket handler |
| Modify | `gateway/Cargo.toml` -- workspace members |
| Modify | `apps/developers/models.py` -- CommunityServer model, new scopes |
| Modify | `apps/developers/oauth_views.py` -- client_credentials grant |
| Modify | `apps/developers/views.py` -- server management endpoints |
| Modify | `apps/developers/schemas.py` -- server schemas |

### Phase 4 (Community Frontend)

| Action | File |
|--------|------|
| Create | `frontend/app/(main)/servers/page.tsx` -- server browser |
| Create | `frontend/app/(main)/servers/[id]/page.tsx` -- server detail |
| Create | `frontend/app/(main)/developers/servers/page.tsx` -- manage servers |
| Create | `frontend/app/(main)/developers/servers/new/page.tsx` -- register server |
| Create | `frontend/app/(main)/developers/servers/[id]/page.tsx` -- server config |
| Create | `gateway/crates/zelqor-gamenode/src/config.rs` -- gamenode config |

### Phase 5 (Plugins)

| Action | File |
|--------|------|
| Create | `gateway/crates/zelqor-plugins/` -- WASM runtime, sandbox, hooks |
| Create | `gateway/crates/zelqor-plugins/wit/plugin.wit` -- WIT contract |
| Modify | `gateway/crates/zelqor-gamenode/src/main.rs` -- plugin loading |
| Modify | `apps/developers/models.py` -- Plugin, PluginVersion models |
| Modify | `apps/developers/views.py` -- plugin management endpoints |
| Modify | `apps/developers/schemas.py` -- plugin schemas |
| Create | `frontend/app/(main)/plugins/page.tsx` -- plugin browser |
| Create | `frontend/app/(main)/plugins/[slug]/page.tsx` -- plugin detail |
| Create | `frontend/app/(main)/developers/plugins/page.tsx` -- manage plugins |
| Create | `frontend/app/(main)/developers/plugins/new/page.tsx` -- upload plugin |

---

## Risk Assessment

1. **Gateway split (Phase 3):** `game.rs` (127KB) is tightly coupled with `AppState`. Extracting to work over WebSocket requires careful refactoring of the game loop.
2. **WASM plugin latency:** 5 plugins x 50ms = 250ms per tick. Mitigation: async hooks for non-critical plugins, fuel-based timeout kills slow plugins.
3. **OAuth scope expansion:** Adding `server:connect` + `client_credentials` grant must not break existing user-facing OAuth flows. The `_verify_client()` function is shared.
4. **Outbox migration:** Use feature flag `OUTBOX_ENABLED` for gradual shift from synchronous to event-driven finalization.
5. **Community server abuse:** Malicious gamenode could report fake match results. Mitigation: server verification system, result validation in gateway, rate limiting per server.
