use dashmap::{DashMap, DashSet};
use maplord_django::DjangoClient;
use serde_json::json;
use std::sync::Arc;
use std::time::Instant;
use tokio::sync::mpsc;
use tracing::{info, warn};

/// How long to wait before filling with bots (seconds).
const BOT_FILL_TIMEOUT_SECS: u64 = 30;

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
    /// Tracks when the first player joined each queue group (for bot fill timeout).
    queue_timers: DashMap<String, Instant>,
    /// Groups where at least one player requested bot fill.
    bot_fill_requested: DashSet<String>,
}

impl MatchmakingManager {
    pub fn new(django: DjangoClient) -> Self {
        Self {
            groups: DashMap::new(),
            django,
            queue_timers: DashMap::new(),
            bot_fill_requested: DashSet::new(),
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

        // Start bot fill timer if this is the first player in the group
        self.queue_timers.entry(group.clone()).or_insert_with(Instant::now);

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
        let group_empty = {
            if let Some(mut connections) = self.groups.get_mut(&group) {
                connections.retain(|c| c.user_id != user_id);
                connections.is_empty()
            } else {
                true
            }
        };

        // Clean up timer and bot fill flag if group is now empty
        if group_empty {
            self.queue_timers.remove(&group);
            self.bot_fill_requested.remove(&group);
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

    /// Called when a player sends the "fill_bots" action.
    /// Marks the group for bot fill and schedules the timeout.
    pub async fn request_bot_fill(self: &Arc<Self>, game_mode: Option<&str>) {
        let group = Self::queue_group_name(game_mode);
        info!("Bot fill requested for group: {group}");
        self.bot_fill_requested.insert(group);
        self.schedule_bot_fill(game_mode).await;
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

    async fn schedule_bot_fill(self: &Arc<Self>, game_mode: Option<&str>) {
        let group = Self::queue_group_name(game_mode);
        let gm = game_mode.map(|s| s.to_string());
        let mgr = Arc::clone(self);

        tokio::spawn(async move {
            tokio::time::sleep(tokio::time::Duration::from_secs(BOT_FILL_TIMEOUT_SECS)).await;

            // Check if the group still has waiting players and timer is still active
            let group_has_players = mgr
                .groups
                .get(&group)
                .map(|c| !c.is_empty())
                .unwrap_or(false);

            if !group_has_players {
                info!("Bot fill skipped for {group}: no players in group");
                return;
            }

            // Check if bot fill was actually requested for this group
            if !mgr.bot_fill_requested.contains(&group) {
                info!("Bot fill skipped for {group}: not requested");
                return;
            }

            // Check if the timer entry is old enough (wasn't reset)
            let elapsed_secs = mgr
                .queue_timers
                .get(&group)
                .map(|t| t.elapsed().as_secs())
                .unwrap_or(0);
            let should_fill = elapsed_secs >= BOT_FILL_TIMEOUT_SECS;

            if !should_fill {
                info!("Bot fill skipped for {group}: timer not old enough (elapsed={elapsed_secs}s)");
                return;
            }

            info!("Bot fill timer fired for {group}, calling try_fill_with_bots");
            mgr.try_fill_with_bots(gm.as_deref()).await;
        });
    }

    async fn try_fill_with_bots(&self, game_mode: Option<&str>) {
        info!("try_fill_with_bots called with game_mode={game_mode:?}");
        let result = match self.django.fill_with_bots(game_mode).await {
            Ok(r) => {
                info!("fill_with_bots response: match_id={:?}, user_ids={:?}, bot_ids={:?}", r.match_id, r.user_ids, r.bot_ids);
                r
            }
            Err(e) => {
                warn!("fill_with_bots failed: {e}");
                return;
            }
        };

        let match_id = match result.match_id {
            Some(id) => id,
            None => {
                info!("fill_with_bots returned no match_id");
                return;
            }
        };
        let user_ids = result.user_ids.unwrap_or_default();

        info!(
            "Bot-filled match created: {match_id} for users: {user_ids:?} (bots: {:?})",
            result.bot_ids
        );

        let group = Self::queue_group_name(game_mode);

        // Notify human players about the match
        if let Some(connections) = self.groups.get(&group) {
            for conn in connections.iter() {
                if user_ids.contains(&conn.user_id) {
                    let _ = conn.sender.send(MatchmakingMessage::Json(json!({
                        "type": "match_found",
                        "match_id": match_id,
                    })));
                    let _ = conn.sender.send(MatchmakingMessage::Close);
                }
            }
        }

        // Remove matched users from local group
        if let Some(mut connections) = self.groups.get_mut(&group) {
            connections.retain(|c| !user_ids.contains(&c.user_id));
            if connections.is_empty() {
                drop(connections);
                self.queue_timers.remove(&group);
                self.bot_fill_requested.remove(&group);
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
            if connections.is_empty() {
                drop(connections);
                self.queue_timers.remove(&group);
                self.bot_fill_requested.remove(&group);
            }
        }
    }
}
