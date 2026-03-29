mod config;

use config::NodeConfig;
use futures_util::{SinkExt, StreamExt};
use serde::Deserialize;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use tokio::time::{interval, Duration};
use tokio_tungstenite::{connect_async, tungstenite::Message};
use tracing::{error, info, warn};
use zelqor_protocol::{GatewayToNode, NodeToGateway};

/// Response body from the OAuth token endpoint.
#[derive(Debug, Deserialize)]
struct TokenResponse {
    access_token: String,
}

/// Obtain an access token from the gateway OAuth endpoint using client credentials.
async fn fetch_access_token(
    client: &reqwest::Client,
    cfg: &NodeConfig,
) -> anyhow::Result<String> {
    let params = [
        ("grant_type", "client_credentials"),
        ("client_id", &cfg.client_id),
        ("client_secret", &cfg.client_secret),
    ];

    let resp = client
        .post(cfg.token_url())
        .form(&params)
        .send()
        .await
        .map_err(|e| anyhow::anyhow!("OAuth request failed: {e}"))?;

    let status = resp.status();
    if !status.is_success() {
        let body = resp.text().await.unwrap_or_default();
        return Err(anyhow::anyhow!(
            "OAuth endpoint returned {status}: {body}"
        ));
    }

    let token_resp: TokenResponse = resp
        .json()
        .await
        .map_err(|e| anyhow::anyhow!("Failed to parse token response: {e}"))?;

    Ok(token_resp.access_token)
}

/// Send a `NodeToGateway` message serialised as a JSON text frame.
async fn send_msg<S>(
    sink: &mut S,
    msg: &NodeToGateway,
) -> Result<(), tokio_tungstenite::tungstenite::Error>
where
    S: SinkExt<Message, Error = tokio_tungstenite::tungstenite::Error> + Unpin,
{
    let text = serde_json::to_string(msg).expect("NodeToGateway is always serializable");
    sink.send(Message::Text(text.into())).await
}

#[tokio::main]
async fn main() {
    // Load .env if present (dev convenience).
    let _ = dotenvy::dotenv();

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,zelqor_gamenode=debug".into()),
        )
        .init();

    let cfg = NodeConfig::from_env();
    info!(
        server_name = %cfg.server_name,
        region = %cfg.region,
        max_matches = cfg.max_matches,
        gateway_url = %cfg.gateway_url,
        "Starting Zelqor Gamenode"
    );

    // Build an HTTP client for OAuth.
    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .expect("Failed to build HTTP client");

    // Shared active-match counter updated as matches start / finish.
    let active_matches: Arc<AtomicU32> = Arc::new(AtomicU32::new(0));

    // Set up shutdown signal handling.
    let shutdown = Arc::new(tokio::sync::Notify::new());
    let shutdown_tx = shutdown.clone();

    tokio::spawn(async move {
        use tokio::signal::unix::{signal, SignalKind};
        let mut sigterm =
            signal(SignalKind::terminate()).expect("Failed to install SIGTERM handler");

        tokio::select! {
            _ = sigterm.recv() => info!("Received SIGTERM"),
            _ = tokio::signal::ctrl_c() => info!("Received SIGINT (Ctrl+C)"),
        }

        info!("Shutdown signal received, initiating graceful shutdown");
        shutdown_tx.notify_waiters();
    });

    // Main connection loop — reconnect on failure.
    loop {
        tokio::select! {
            _ = shutdown.notified() => {
                info!("Gamenode shutting down cleanly");
                break;
            }
            _ = run_connection(&cfg, &http_client, active_matches.clone()) => {
                warn!("Gateway connection closed, reconnecting in 5 seconds...");
                tokio::time::sleep(Duration::from_secs(5)).await;
            }
        }
    }
}

/// Establish a single connection lifecycle: authenticate, connect, register, run loop.
async fn run_connection(
    cfg: &NodeConfig,
    http_client: &reqwest::Client,
    active_matches: Arc<AtomicU32>,
) {
    // 1. Obtain access token.
    let access_token = match fetch_access_token(http_client, cfg).await {
        Ok(t) => {
            info!("Successfully obtained access token");
            t
        }
        Err(e) => {
            error!("Failed to obtain access token: {e}");
            return;
        }
    };

    // 2. Connect to gateway WebSocket.
    let ws_url = cfg.ws_url(&access_token);
    info!(url = %ws_url, "Connecting to gateway WebSocket");

    let (ws_stream, _response) = match connect_async(&ws_url).await {
        Ok(pair) => pair,
        Err(e) => {
            error!("WebSocket connection failed: {e}");
            return;
        }
    };

    info!("Connected to gateway");
    let (mut ws_sink, mut ws_source) = ws_stream.split();

    // 3. Send Register message.
    let register_msg = NodeToGateway::Register {
        server_id: cfg.client_id.clone(),
        server_name: cfg.server_name.clone(),
        region: cfg.region.clone(),
        max_matches: cfg.max_matches,
    };

    if let Err(e) = send_msg(&mut ws_sink, &register_msg).await {
        error!("Failed to send Register message: {e}");
        return;
    }

    info!(
        server_id = %cfg.client_id,
        region = %cfg.region,
        max_matches = cfg.max_matches,
        "Sent Register to gateway"
    );

    // 4. Spawn heartbeat task.
    let (hb_tx, mut hb_rx) = tokio::sync::mpsc::unbounded_channel::<NodeToGateway>();
    let active_matches_hb = active_matches.clone();

    tokio::spawn(async move {
        let mut ticker = interval(Duration::from_secs(10));
        loop {
            ticker.tick().await;
            let ack = NodeToGateway::HeartbeatAck {
                active_matches: active_matches_hb.load(Ordering::Relaxed),
                // cpu_load is a stub — real implementation would query sysinfo.
                cpu_load: 0.0,
            };
            if hb_tx.send(ack).is_err() {
                // Receiver dropped — connection is gone.
                break;
            }
        }
    });

    // 5. Main message loop.
    loop {
        tokio::select! {
            // Outbound: heartbeats queued by the heartbeat task.
            Some(msg) = hb_rx.recv() => {
                if let Err(e) = send_msg(&mut ws_sink, &msg).await {
                    error!("Failed to send heartbeat: {e}");
                    break;
                }
                info!("Sent HeartbeatAck to gateway");
            }

            // Inbound: messages from the gateway.
            maybe_msg = ws_source.next() => {
                match maybe_msg {
                    Some(Ok(Message::Text(text))) => {
                        handle_gateway_message(&text, active_matches.clone());
                    }
                    Some(Ok(Message::Ping(data))) => {
                        // Respond to ping frames.
                        if let Err(e) = ws_sink.send(Message::Pong(data)).await {
                            error!("Failed to send Pong: {e}");
                            break;
                        }
                    }
                    Some(Ok(Message::Close(frame))) => {
                        info!(?frame, "Gateway closed connection");
                        break;
                    }
                    Some(Ok(_)) => {
                        // Binary / Pong frames — ignore.
                    }
                    Some(Err(e)) => {
                        error!("WebSocket error: {e}");
                        break;
                    }
                    None => {
                        info!("Gateway stream ended");
                        break;
                    }
                }
            }
        }
    }
}

/// Dispatch a single inbound text frame from the gateway.
fn handle_gateway_message(text: &str, active_matches: Arc<AtomicU32>) {
    let msg: GatewayToNode = match serde_json::from_str(text) {
        Ok(m) => m,
        Err(e) => {
            warn!("Failed to parse gateway message: {e} | raw: {text}");
            return;
        }
    };

    match msg {
        GatewayToNode::StartMatch {
            ref match_id,
            ref match_data,
        } => {
            info!(match_id = %match_id, "Received StartMatch");
            // TODO: integrate with zelqor-engine to launch game loop.
            active_matches.fetch_add(1, Ordering::Relaxed);
            let _ = match_data; // Will be used when game loop is wired up.
        }
        GatewayToNode::PlayerAction {
            ref match_id,
            ref user_id,
            ref action,
        } => {
            info!(match_id = %match_id, user_id = %user_id, "Received PlayerAction");
            // TODO: forward to the running game loop for this match.
            let _ = action;
        }
        GatewayToNode::PlayerConnect {
            ref match_id,
            ref user_id,
        } => {
            info!(match_id = %match_id, user_id = %user_id, "Player connected to match");
        }
        GatewayToNode::PlayerDisconnect {
            ref match_id,
            ref user_id,
        } => {
            info!(match_id = %match_id, user_id = %user_id, "Player disconnected from match");
        }
        GatewayToNode::Heartbeat => {
            info!("Received Heartbeat ping from gateway");
            // The periodic HeartbeatAck is handled by the heartbeat task; this
            // handles an explicit ping if the gateway sends one outside the interval.
        }
    }
}
