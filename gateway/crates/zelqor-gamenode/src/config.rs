/// Configuration for the gamenode, loaded from environment variables.
#[derive(Debug, Clone)]
pub struct NodeConfig {
    /// OAuth client ID used to authenticate with the gateway.
    pub client_id: String,
    /// OAuth client secret used to authenticate with the gateway.
    pub client_secret: String,
    /// Base URL of the central gateway (e.g. `http://gateway:8080`).
    pub gateway_url: String,
    /// Redis connection URL (e.g. `redis://redis:6379/1`).
    pub redis_url: String,
    /// Human-readable name for this server node.
    pub server_name: String,
    /// Geographic region identifier (e.g. `eu-west`, `us-east`).
    pub region: String,
    /// Maximum number of concurrent matches this node will host.
    pub max_matches: u32,
}

impl NodeConfig {
    /// Load configuration from environment variables with sensible dev defaults.
    pub fn from_env() -> Self {
        Self {
            client_id: std::env::var("CLIENT_ID")
                .unwrap_or_else(|_| "gamenode-dev".into()),
            client_secret: std::env::var("CLIENT_SECRET")
                .unwrap_or_else(|_| "dev-secret".into()),
            gateway_url: std::env::var("GATEWAY_URL")
                .unwrap_or_else(|_| "http://gateway:8080".into()),
            redis_url: std::env::var("REDIS_URL")
                .unwrap_or_else(|_| "redis://redis:6379/1".into()),
            server_name: std::env::var("SERVER_NAME")
                .unwrap_or_else(|_| "Dev Gamenode".into()),
            region: std::env::var("REGION")
                .unwrap_or_else(|_| "dev".into()),
            max_matches: std::env::var("MAX_MATCHES")
                .unwrap_or_else(|_| "10".into())
                .parse()
                .unwrap_or(10),
        }
    }

    /// Derive the WebSocket URL for the server connection endpoint.
    ///
    /// Converts `http://` to `ws://` and `https://` to `wss://`.
    pub fn ws_url(&self, token: &str) -> String {
        let base = self
            .gateway_url
            .replace("https://", "wss://")
            .replace("http://", "ws://");
        format!("{base}/ws/server/?token={token}")
    }

    /// Return the OAuth token endpoint URL.
    pub fn token_url(&self) -> String {
        format!("{}/oauth/token/", self.gateway_url)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ws_url_converts_http_to_ws() {
        let cfg = NodeConfig {
            client_id: "id".into(),
            client_secret: "secret".into(),
            gateway_url: "http://gateway:8080".into(),
            redis_url: "redis://redis:6379/1".into(),
            server_name: "test".into(),
            region: "dev".into(),
            max_matches: 5,
        };
        let url = cfg.ws_url("my-token");
        assert!(url.starts_with("ws://"));
        assert!(url.contains("/ws/server/?token=my-token"));
    }

    #[test]
    fn ws_url_converts_https_to_wss() {
        let cfg = NodeConfig {
            client_id: "id".into(),
            client_secret: "secret".into(),
            gateway_url: "https://gateway.zelqor.com".into(),
            redis_url: "redis://redis:6379/1".into(),
            server_name: "prod".into(),
            region: "eu-west".into(),
            max_matches: 20,
        };
        let url = cfg.ws_url("tok");
        assert!(url.starts_with("wss://"));
    }

    #[test]
    fn token_url_appends_path() {
        let cfg = NodeConfig {
            client_id: "id".into(),
            client_secret: "secret".into(),
            gateway_url: "http://gateway:8080".into(),
            redis_url: "redis://redis:6379/1".into(),
            server_name: "test".into(),
            region: "dev".into(),
            max_matches: 5,
        };
        assert_eq!(cfg.token_url(), "http://gateway:8080/oauth/token/");
    }

    #[test]
    fn max_matches_defaults_to_10_on_invalid_env() {
        // Simulate what from_env does with an unparseable value.
        let result: u32 = "not-a-number".parse().unwrap_or(10);
        assert_eq!(result, 10);
    }
}
