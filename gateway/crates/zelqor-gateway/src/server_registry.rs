use dashmap::DashMap;
use std::time::Instant;
use tokio::sync::mpsc;
use zelqor_protocol::GatewayToNode;

/// A gamenode that is currently connected to the gateway.
pub struct ConnectedServer {
    pub server_id: String,
    pub server_name: String,
    /// Channel used to push messages from the gateway to this gamenode.
    pub sender: mpsc::UnboundedSender<GatewayToNode>,
    /// Number of active matches currently running on this node.
    pub active_matches: u32,
    /// Maximum number of matches this node will host simultaneously.
    pub max_matches: u32,
    /// Geographic region (e.g. `eu-west`, `us-east`).
    pub region: String,
    /// Timestamp of the last received heartbeat (used for stale-node detection).
    pub last_heartbeat: Instant,
    /// Whether this is a first-party (official) server.
    pub is_official: bool,
}

/// Registry of all gamenode servers connected to the gateway.
pub struct ServerRegistry {
    servers: DashMap<String, ConnectedServer>,
}

impl ServerRegistry {
    /// Create an empty registry.
    pub fn new() -> Self {
        Self {
            servers: DashMap::new(),
        }
    }

    /// Register a newly connected gamenode.
    pub fn register(&self, server: ConnectedServer) {
        tracing::info!(
            server_id = %server.server_id,
            server_name = %server.server_name,
            region = %server.region,
            max_matches = server.max_matches,
            is_official = server.is_official,
            "Registering gamenode"
        );
        self.servers.insert(server.server_id.clone(), server);
    }

    /// Remove a gamenode when it disconnects.
    pub fn unregister(&self, server_id: &str) {
        if self.servers.remove(server_id).is_some() {
            tracing::info!(server_id = %server_id, "Unregistered gamenode");
        } else {
            tracing::warn!(server_id = %server_id, "Tried to unregister unknown gamenode");
        }
    }

    /// Find the best available server, optionally preferring a specific region.
    ///
    /// Selection criteria (in priority order):
    /// 1. Servers in the requested region (when `region` is `Some`).
    /// 2. Lowest active_matches / max_matches utilisation ratio.
    /// 3. Servers that still have capacity (active < max).
    ///
    /// Returns the `server_id` of the chosen server, or `None` when no server
    /// with remaining capacity is available.
    pub fn get_best_server(&self, region: Option<&str>) -> Option<String> {
        let mut best_id: Option<String> = None;
        let mut best_ratio = f64::MAX;

        for entry in self.servers.iter() {
            let server = entry.value();

            // Skip saturated nodes.
            if server.active_matches >= server.max_matches {
                continue;
            }

            let ratio = if server.max_matches == 0 {
                f64::MAX
            } else {
                server.active_matches as f64 / server.max_matches as f64
            };

            // Region preference: when the caller asks for a specific region we
            // give those servers an artificial head start over non-matching ones.
            let effective_ratio = match region {
                Some(req_region) if server.region == req_region => ratio - 1.0,
                _ => ratio,
            };

            if effective_ratio < best_ratio {
                best_ratio = effective_ratio;
                best_id = Some(server.server_id.clone());
            }
        }

        best_id
    }

    /// Update heartbeat timestamp and active-match count for a server.
    pub fn update_heartbeat(&self, server_id: &str, active_matches: u32, cpu_load: f32) {
        if let Some(mut entry) = self.servers.get_mut(server_id) {
            entry.active_matches = active_matches;
            entry.last_heartbeat = Instant::now();
            tracing::debug!(
                server_id = %server_id,
                active_matches,
                cpu_load,
                "Updated heartbeat"
            );
        } else {
            tracing::warn!(
                server_id = %server_id,
                "Received heartbeat from unknown server"
            );
        }
    }

    /// Return the total number of registered servers.
    pub fn server_count(&self) -> usize {
        self.servers.len()
    }
}

impl Default for ServerRegistry {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::mpsc;

    fn make_server(id: &str, region: &str, active: u32, max: u32) -> ConnectedServer {
        let (tx, _rx) = mpsc::unbounded_channel();
        ConnectedServer {
            server_id: id.to_string(),
            server_name: format!("{id}-name"),
            sender: tx,
            active_matches: active,
            max_matches: max,
            region: region.to_string(),
            last_heartbeat: Instant::now(),
            is_official: false,
        }
    }

    #[test]
    fn register_and_count() {
        let registry = ServerRegistry::new();
        assert_eq!(registry.server_count(), 0);
        registry.register(make_server("s1", "eu-west", 0, 10));
        assert_eq!(registry.server_count(), 1);
    }

    #[test]
    fn unregister_removes_server() {
        let registry = ServerRegistry::new();
        registry.register(make_server("s1", "eu-west", 0, 10));
        registry.unregister("s1");
        assert_eq!(registry.server_count(), 0);
    }

    #[test]
    fn unregister_unknown_does_not_panic() {
        let registry = ServerRegistry::new();
        registry.unregister("nonexistent"); // Must not panic.
    }

    #[test]
    fn get_best_server_returns_none_when_empty() {
        let registry = ServerRegistry::new();
        assert_eq!(registry.get_best_server(None), None);
    }

    #[test]
    fn get_best_server_returns_none_when_all_saturated() {
        let registry = ServerRegistry::new();
        registry.register(make_server("s1", "eu-west", 10, 10));
        assert_eq!(registry.get_best_server(None), None);
    }

    #[test]
    fn get_best_server_picks_least_loaded() {
        let registry = ServerRegistry::new();
        registry.register(make_server("busy", "eu-west", 8, 10));
        registry.register(make_server("idle", "eu-west", 1, 10));
        let best = registry.get_best_server(None).expect("should find a server");
        assert_eq!(best, "idle");
    }

    #[test]
    fn get_best_server_prefers_requested_region() {
        let registry = ServerRegistry::new();
        // us server is slightly less loaded but eu is in the preferred region.
        registry.register(make_server("us-node", "us-east", 2, 10));
        registry.register(make_server("eu-node", "eu-west", 5, 10));
        let best = registry
            .get_best_server(Some("eu-west"))
            .expect("should find a server");
        assert_eq!(best, "eu-node");
    }

    #[test]
    fn update_heartbeat_refreshes_active_matches() {
        let registry = ServerRegistry::new();
        registry.register(make_server("s1", "eu-west", 0, 10));
        registry.update_heartbeat("s1", 5, 0.3);
        let entry = registry.servers.get("s1").unwrap();
        assert_eq!(entry.active_matches, 5);
    }

    #[test]
    fn update_heartbeat_unknown_server_does_not_panic() {
        let registry = ServerRegistry::new();
        registry.update_heartbeat("ghost", 1, 0.1); // Must not panic.
    }
}
