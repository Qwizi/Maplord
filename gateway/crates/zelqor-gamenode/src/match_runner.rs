use dashmap::DashMap;
use std::sync::Arc;
use tokio::sync::mpsc;

/// Commands sent from the main connection loop into a running match task.
pub enum MatchCommand {
    PlayerAction {
        user_id: String,
        action: serde_json::Value,
    },
    PlayerConnect {
        user_id: String,
    },
    PlayerDisconnect {
        user_id: String,
    },
    Stop,
}

/// Results sent from a match task back to the main connection loop so the
/// loop can forward them to the gateway as `NodeToGateway` messages.
pub enum MatchResult {
    Tick {
        match_id: String,
        tick: u64,
        tick_data: serde_json::Value,
    },
    Finished {
        match_id: String,
        winner_id: Option<String>,
        total_ticks: u64,
        final_state: serde_json::Value,
    },
    PlayerEliminated {
        match_id: String,
        user_id: String,
    },
}

/// Manages active game matches on this gamenode.
///
/// Each match runs in its own tokio task. `MatchRunner` holds a sender for
/// each task so commands (player actions, connect/disconnect, stop) can be
/// forwarded without blocking the gateway I/O loop.
pub struct MatchRunner {
    /// match_id → sender for forwarding commands into the match task.
    matches: Arc<DashMap<String, mpsc::UnboundedSender<MatchCommand>>>,
}

impl MatchRunner {
    pub fn new() -> Self {
        Self {
            matches: Arc::new(DashMap::new()),
        }
    }

    /// Start a new match in a background task.
    ///
    /// `result_tx` is used by the task to send tick updates, elimination
    /// events, and the final result back to the caller's select loop.
    pub fn start_match(
        &self,
        match_id: String,
        match_data: serde_json::Value,
        result_tx: mpsc::UnboundedSender<MatchResult>,
    ) {
        let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<MatchCommand>();
        self.matches.insert(match_id.clone(), cmd_tx);

        let matches = self.matches.clone();
        tokio::spawn(async move {
            tracing::info!(match_id = %match_id, "Match started");
            let _ = match_data; // will be used when zelqor-engine is wired in

            // Run game loop at 1 tick per second.
            let mut tick: u64 = 0;
            let mut ticker =
                tokio::time::interval(tokio::time::Duration::from_secs(1));

            loop {
                tokio::select! {
                    _ = ticker.tick() => {
                        tick += 1;
                        // Engine tick processing goes here using zelqor_engine.
                        // For now send a minimal tick result back to the gateway.
                        let tick_data = serde_json::json!({
                            "tick": tick,
                            "match_id": match_id,
                        });
                        let _ = result_tx.send(MatchResult::Tick {
                            match_id: match_id.clone(),
                            tick,
                            tick_data,
                        });
                    }
                    Some(cmd) = cmd_rx.recv() => {
                        match cmd {
                            MatchCommand::PlayerAction { user_id, action } => {
                                tracing::debug!(
                                    match_id = %match_id,
                                    user_id = %user_id,
                                    "Processing action"
                                );
                                // Engine would process the action here.
                                let _ = action;
                            }
                            MatchCommand::PlayerConnect { user_id } => {
                                tracing::info!(
                                    match_id = %match_id,
                                    user_id = %user_id,
                                    "Player connected"
                                );
                            }
                            MatchCommand::PlayerDisconnect { user_id } => {
                                tracing::info!(
                                    match_id = %match_id,
                                    user_id = %user_id,
                                    "Player disconnected"
                                );
                            }
                            MatchCommand::Stop => {
                                tracing::info!(match_id = %match_id, "Match stopped");
                                break;
                            }
                        }
                    }
                }
            }

            matches.remove(&match_id);
            tracing::info!(match_id = %match_id, tick, "Match ended after {tick} ticks");
        });
    }

    /// Forward a command to a running match.
    ///
    /// Returns `true` if the message was enqueued, `false` if no match with
    /// that ID is currently running.
    pub fn send_command(&self, match_id: &str, cmd: MatchCommand) -> bool {
        if let Some(tx) = self.matches.get(match_id) {
            tx.send(cmd).is_ok()
        } else {
            tracing::warn!(match_id = %match_id, "No running match found");
            false
        }
    }

    /// Number of currently active matches.
    pub fn active_count(&self) -> u32 {
        self.matches.len() as u32
    }
}
