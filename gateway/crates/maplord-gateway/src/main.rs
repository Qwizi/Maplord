mod auth;
mod config;
mod game;
mod matchmaking_ws;
mod state;

use axum::{
    routing::get,
    Router,
};
use maplord_django::DjangoClient;
use maplord_matchmaking::MatchmakingManager;
use std::sync::Arc;
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tracing::info;

use crate::config::AppConfig;
use crate::game::new_game_connections;
use crate::state::AppState;

#[tokio::main]
async fn main() {
    // Load .env
    let _ = dotenvy::dotenv();

    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,maplord_gateway=debug".into()),
        )
        .init();

    let config = AppConfig::from_env();
    info!("Starting MapLord Gateway on port {}", config.gateway_port);

    // Connect to Redis
    let redis_client = redis::Client::open(config.redis_url())
        .expect("Failed to create Redis client");
    let redis_conn = redis::aio::ConnectionManager::new(redis_client)
        .await
        .expect("Failed to connect to Redis");

    // Create Django client
    let django = DjangoClient::new(
        config.django_internal_url.clone(),
        config.internal_secret.clone(),
    );

    // Create matchmaking manager
    let matchmaking = Arc::new(MatchmakingManager::new(django.clone()));

    // Create game connections registry
    let game_connections = new_game_connections();

    let app_state = AppState {
        config: config.clone(),
        redis: redis_conn,
        django,
        matchmaking,
        game_connections,
    };

    let app = Router::new()
        // Health check
        .route("/health", get(|| async { "OK" }))
        // Matchmaking WebSocket routes
        .route(
            "/ws/matchmaking/",
            get(|ws, state, query| {
                matchmaking_ws::ws_matchmaking_handler(ws, None, state, query)
            }),
        )
        .route(
            "/ws/matchmaking/{game_mode}/",
            get(|ws, path: axum::extract::Path<String>, state, query| {
                matchmaking_ws::ws_matchmaking_handler(
                    ws,
                    Some(axum::extract::Path(path.0)),
                    state,
                    query,
                )
            }),
        )
        // Game WebSocket route
        .route("/ws/game/{match_id}/", get(game::ws_game_handler))
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(app_state);

    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", config.gateway_port))
        .await
        .expect("Failed to bind");

    info!("Listening on 0.0.0.0:{}", config.gateway_port);
    axum::serve(listener, app).await.expect("Server failed");
}
