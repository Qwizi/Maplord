use crate::auth;
use crate::state::AppState;
use axum::extract::ws::{Message, WebSocket};
use axum::extract::{Path, State, WebSocketUpgrade};
use axum::response::Response;
use maplord_matchmaking::MatchmakingMessage;

use serde::Deserialize;

#[derive(Deserialize)]
pub struct TokenQuery {
    pub token: Option<String>,
}

pub async fn ws_matchmaking_handler(
    ws: WebSocketUpgrade,
    game_mode: Option<Path<String>>,
    State(state): State<AppState>,
    axum_extra::extract::Query(query): axum_extra::extract::Query<TokenQuery>,
) -> Response {
    let token = match query.token {
        Some(t) => t,
        None => {
            return Response::builder()
                .status(401)
                .body("Missing token".into())
                .unwrap();
        }
    };

    let user_id = match auth::validate_token(&token, &state.config.secret_key) {
        Ok(id) => id,
        Err(_) => {
            return Response::builder()
                .status(401)
                .body("Invalid token".into())
                .unwrap();
        }
    };

    let game_mode_slug = game_mode.map(|p| p.0);

    ws.on_upgrade(move |socket| handle_matchmaking_socket(socket, user_id, game_mode_slug, state))
}

async fn handle_matchmaking_socket(
    socket: WebSocket,
    user_id: String,
    game_mode: Option<String>,
    state: AppState,
) {
    use futures::{SinkExt, StreamExt};
    let (mut ws_sender, mut ws_receiver) = socket.split();

    let game_mode_ref = game_mode.as_deref();
    let mut rx = match state
        .matchmaking
        .connect(&user_id, game_mode_ref)
        .await
    {
        Ok(rx) => rx,
        Err(e) => {
            let _ = ws_sender
                .send(Message::Text(
                    serde_json::json!({"type": "error", "message": e})
                        .to_string()
                        .into(),
                ))
                .await;
            return;
        }
    };

    // Forward outgoing messages to WebSocket
    let send_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            match msg {
                MatchmakingMessage::Json(val) => {
                    if ws_sender
                        .send(Message::Text(val.to_string().into()))
                        .await
                        .is_err()
                    {
                        break;
                    }
                }
                MatchmakingMessage::Close => {
                    let _ = ws_sender.close().await;
                    break;
                }
            }
        }
    });

    // Process incoming messages
    let matchmaking = state.matchmaking.clone();
    let user_id_clone = user_id.clone();
    let game_mode_clone = game_mode.clone();

    let recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_receiver.next().await {
            match msg {
                Message::Text(text) => {
                    if let Ok(content) = serde_json::from_str::<serde_json::Value>(&text) {
                        let action = content
                            .get("action")
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        match action {
                            "cancel" => {
                                matchmaking
                                    .handle_cancel(
                                        &user_id_clone,
                                        game_mode_clone.as_deref(),
                                    )
                                    .await;
                                break;
                            }
                            "status" => {
                                matchmaking
                                    .handle_status(
                                        &user_id_clone,
                                        game_mode_clone.as_deref(),
                                    )
                                    .await;
                            }
                            "fill_bots" => {
                                matchmaking
                                    .request_bot_fill(
                                        game_mode_clone.as_deref(),
                                    )
                                    .await;
                            }
                            "instant_bot" => {
                                matchmaking
                                    .request_bot_fill(
                                        game_mode_clone.as_deref(),
                                    )
                                    .await;
                                matchmaking
                                    .instant_bot_fill(
                                        game_mode_clone.as_deref(),
                                    )
                                    .await;
                            }
                            _ => {}
                        }
                    }
                }
                Message::Close(_) => break,
                _ => {}
            }
        }
    });

    tokio::select! {
        _ = send_task => {},
        _ = recv_task => {},
    }

    // Cleanup on disconnect
    state
        .matchmaking
        .disconnect(&user_id, game_mode.as_deref())
        .await;
}
