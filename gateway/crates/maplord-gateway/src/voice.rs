use livekit_api::access_token::{AccessToken, VideoGrants};

/// Generate a LiveKit access token for a player joining a match voice room.
///
/// - `room_name`  — LiveKit room identifier (equals the match UUID)
/// - `user_id`    — participant identity embedded in the JWT `sub` claim
/// - `username`   — human-readable display name embedded in the JWT `name` claim
///
/// The token is valid for 24 hours and grants the participant permission to join
/// the room, publish audio/video, and subscribe to other participants.
pub fn generate_voice_token(
    api_key: &str,
    api_secret: &str,
    room_name: &str,
    user_id: &str,
    username: &str,
) -> Result<String, String> {
    let grants = VideoGrants {
        room_join: true,
        room: room_name.to_string(),
        can_publish: true,
        can_subscribe: true,
        ..Default::default()
    };

    AccessToken::with_api_key(api_key, api_secret)
        .with_identity(user_id)
        .with_name(username)
        .with_grants(grants)
        .with_ttl(std::time::Duration::from_secs(86400))
        .to_jwt()
        .map_err(|e| format!("Failed to generate LiveKit token: {e}"))
}
