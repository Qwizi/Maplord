use jsonwebtoken::{decode, DecodingKey, Validation, Algorithm};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub user_id: String,
    pub exp: usize,
    #[serde(default)]
    pub iat: usize,
    #[serde(default)]
    pub jti: String,
    #[serde(default)]
    pub token_type: String,
}

/// Validate a JWT token and extract the user_id.
pub fn validate_token(token: &str, secret: &str) -> Result<String, String> {
    let mut validation = Validation::new(Algorithm::HS256);
    // Django's ninja_jwt doesn't require audience
    validation.validate_aud = false;
    // Required claims
    validation.required_spec_claims.clear();
    validation.required_spec_claims.insert("exp".to_string());
    validation.required_spec_claims.insert("user_id".to_string());

    let token_data = decode::<Claims>(
        token,
        &DecodingKey::from_secret(secret.as_bytes()),
        &validation,
    )
    .map_err(|e| format!("JWT validation failed: {e}"))?;

    Ok(token_data.claims.user_id)
}
