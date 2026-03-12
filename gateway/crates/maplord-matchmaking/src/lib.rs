use dashmap::DashMap;
use maplord_django::DjangoClient;
use serde_json::json;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{info, warn};

/// Message sent to a matchmaking WebSocket connection.
#[derive(Debug, Clone)]
pub enum MatchmakingMessage {
    Json(serde_json::Value),
    Close,
}

/// Per-connection handle stored in the group map.
struct ConnectionHandle {
    user_id: String,
    sender: mpsc::UnboundedSender<MatchmakingMessage>,
}

/// Manages matchmaking WebSocket connections grouped by queue name.
pub struct MatchmakingManager {
    /// queue_group_name -> Vec<ConnectionHandle>
    groups: DashMap<String, Vec<ConnectionHandle>>,
    django: DjangoClient,
}

impl MatchmakingManager {
    pub fn new(django: DjangoClient) -> Self {
        Self {
            groups: DashMap::new(),
            django,
        }
    }

    fn queue_group_name(game_mode: Option<&str>) -> String {
        match game_mode {
            Some(gm) => format!("matchmaking_queue_{gm}"),
            None => "matchmaking_queue".to_string(),
        }
    }

    /// Handle a new matchmaking WebSocket connection.
    /// Returns a receiver for outgoing messages.
    pub async fn connect(
        self: &Arc<Self>,
        user_id: &str,
        game_mode: Option<&str>,
    ) -> Result<mpsc::UnboundedReceiver<MatchmakingMessage>, String> {
        let (tx, rx) = mpsc::unbounded_channel();
        let group = Self::queue_group_name(game_mode);

        // Check for active match first
        match self.django.get_active_match(user_id).await {
            Ok(Some(match_id)) => {
                let _ = self.django.remove_from_queue(user_id).await;
                let _ = tx.send(MatchmakingMessage::Json(json!({
                    "type": "active_match_exists",
                    "match_id": match_id,
                })));
                let _ = tx.send(MatchmakingMessage::Close);
                return Ok(rx);
            }
            Ok(None) => {}
            Err(e) => {
                warn!("Failed to check active match for {user_id}: {e}");
            }
        }

        // Add to Django queue
        if let Err(e) = self.django.add_to_queue(user_id, game_mode).await {
            warn!("Failed to add {user_id} to queue: {e}");
            return Err(format!("Failed to join queue: {e}"));
        }

        // Register in local group
        self.groups
            .entry(group.clone())
            .or_default()
            .push(ConnectionHandle {
                user_id: user_id.to_string(),
                sender: tx,
            });

        // Broadcast queue count
        self.broadcast_queue_count(game_mode).await;

        // Try to create match
        self.try_match(game_mode).await;

        Ok(rx)
    }

    /// Handle disconnection.
    pub async fn disconnect(&self, user_id: &str, game_mode: Option<&str>) {
        let group = Self::queue_group_name(game_mode);

        // Remove from local group
        if let Some(mut connections) = self.groups.get_mut(&group) {
            connections.retain(|c| c.user_id != user_id);
        }

        // Remove from Django queue
        let _ = self.django.remove_from_queue(user_id).await;

        // Broadcast updated count
        self.broadcast_queue_count(game_mode).await;
    }

    /// Handle cancel action from client.
    pub async fn handle_cancel(&self, user_id: &str, game_mode: Option<&str>) {
        let group = Self::queue_group_name(game_mode);

        // Remove from Django queue
        let _ = self.django.remove_from_queue(user_id).await;

        // Send confirmation and close
        if let Some(connections) = self.groups.get(&group) {
            for conn in connections.iter() {
                if conn.user_id == user_id {
                    let _ = conn.sender.send(MatchmakingMessage::Json(json!({
                        "type": "queue_left",
                    })));
                    let _ = conn.sender.send(MatchmakingMessage::Close);
                }
            }
        }

        // Remove from local group
        if let Some(mut connections) = self.groups.get_mut(&group) {
            connections.retain(|c| c.user_id != user_id);
        }

        self.broadcast_queue_count(game_mode).await;
    }

    /// Handle status request.
    pub async fn handle_status(
        &self,
        user_id: &str,
        game_mode: Option<&str>,
    ) {
        let count = self
            .django
            .get_queue_count(game_mode)
            .await
            .unwrap_or(0);
        let group = Self::queue_group_name(game_mode);

        if let Some(connections) = self.groups.get(&group) {
            for conn in connections.iter() {
                if conn.user_id == user_id {
                    let _ = conn.sender.send(MatchmakingMessage::Json(json!({
                        "type": "queue_status",
                        "players_in_queue": count,
                    })));
                }
            }
        }
    }

    async fn broadcast_queue_count(&self, game_mode: Option<&str>) {
        let count = self
            .django
            .get_queue_count(game_mode)
            .await
            .unwrap_or(0);
        let group = Self::queue_group_name(game_mode);

        if let Some(connections) = self.groups.get(&group) {
            let msg = json!({
                "type": "queue_status",
                "players_in_queue": count,
            });
            for conn in connections.iter() {
                let _ = conn
                    .sender
                    .send(MatchmakingMessage::Json(msg.clone()));
            }
        }
    }

    async fn try_match(&self, game_mode: Option<&str>) {
        let result = match self.django.try_match(game_mode).await {
            Ok(r) => r,
            Err(e) => {
                warn!("try_match failed: {e}");
                return;
            }
        };

        let match_id = match result.match_id {
            Some(id) => id,
            None => return,
        };
        let user_ids = result.user_ids.unwrap_or_default();

        info!("Match created: {match_id} for users: {user_ids:?}");

        let group = Self::queue_group_name(game_mode);
        if let Some(connections) = self.groups.get(&group) {
            for conn in connections.iter() {
                if user_ids.contains(&conn.user_id) {
                    let _ = conn.sender.send(MatchmakingMessage::Json(json!({
                        "type": "match_found",
                        "match_id": match_id,
                    })));
                    let _ = conn.sender.send(MatchmakingMessage::Close);
                } else {
                    // Not in this match, update queue count
                    let count = self
                        .django
                        .get_queue_count(game_mode)
                        .await
                        .unwrap_or(0);
                    let _ = conn.sender.send(MatchmakingMessage::Json(json!({
                        "type": "queue_status",
                        "players_in_queue": count,
                    })));
                }
            }
        }

        // Remove matched users from local group
        if let Some(mut connections) = self.groups.get_mut(&group) {
            connections.retain(|c| !user_ids.contains(&c.user_id));
        }
    }
}
