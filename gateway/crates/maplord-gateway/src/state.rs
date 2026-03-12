use crate::config::AppConfig;
use crate::game::GameConnections;
use maplord_django::DjangoClient;
use maplord_matchmaking::MatchmakingManager;
use std::sync::Arc;

/// Shared application state available to all handlers.
#[derive(Clone)]
pub struct AppState {
    pub config: AppConfig,
    pub redis: redis::aio::ConnectionManager,
    pub django: DjangoClient,
    pub matchmaking: Arc<MatchmakingManager>,
    pub game_connections: GameConnections,
}
