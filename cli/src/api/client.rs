use anyhow::{bail, Context, Result};
use reqwest::{Client, StatusCode};

use super::models::*;

pub struct ApiClient {
    client: Client,
    base_url: String,
    access_token: Option<String>,
}

impl ApiClient {
    pub fn new(base_url: &str, access_token: Option<&str>) -> Self {
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .expect("Failed to build HTTP client");

        Self {
            client,
            base_url: base_url.trim_end_matches('/').to_string(),
            access_token: access_token.map(|t| t.to_string()),
        }
    }

    fn auth_headers(&self) -> reqwest::header::HeaderMap {
        let mut headers = reqwest::header::HeaderMap::new();
        if let Some(token) = &self.access_token {
            headers.insert(
                "Authorization",
                format!("Bearer {token}").parse().expect("Invalid auth header"),
            );
        }
        headers
    }

    async fn handle_error(resp: reqwest::Response) -> anyhow::Error {
        let status = resp.status();
        let body = resp.text().await.unwrap_or_else(|_| "<no body>".to_string());
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(&body) {
            if let Some(detail) = v.get("detail").and_then(|d| d.as_str()) {
                return anyhow::anyhow!("API error {}: {}", status, detail);
            }
        }
        anyhow::anyhow!("API error {}: {}", status, body)
    }

    // -------------------------------------------------------------------------
    // OAuth
    // -------------------------------------------------------------------------

    /// Exchange an authorization code for tokens.
    pub async fn exchange_code(
        base_url: &str,
        client_id: &str,
        client_secret: &str,
        code: &str,
        redirect_uri: &str,
    ) -> Result<TokenResponse> {
        let client = Client::new();
        let url = format!("{}/oauth/token/", base_url.trim_end_matches('/'));
        let body = serde_json::json!({
            "grant_type": "authorization_code",
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "redirect_uri": redirect_uri,
        });
        let resp = client
            .post(&url)
            .json(&body)
            .send()
            .await
            .context("Failed to exchange authorization code")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        resp.json().await.context("Failed to parse token response")
    }

    /// Refresh an access token.
    pub async fn refresh_token(
        base_url: &str,
        client_id: &str,
        client_secret: &str,
        refresh_token: &str,
    ) -> Result<TokenResponse> {
        let client = Client::new();
        let url = format!("{}/oauth/token/", base_url.trim_end_matches('/'));
        let body = serde_json::json!({
            "grant_type": "refresh_token",
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
        });
        let resp = client
            .post(&url)
            .json(&body)
            .send()
            .await
            .context("Failed to refresh token")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        resp.json().await.context("Failed to parse token response")
    }

    /// Validate the current token by listing apps.
    pub async fn validate(&self) -> Result<()> {
        let url = format!("{}/developers/apps/?limit=1", self.base_url);
        let resp = self
            .client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Network error while validating token")?;

        if resp.status() == StatusCode::OK {
            Ok(())
        } else {
            Err(Self::handle_error(resp).await)
        }
    }

    // -------------------------------------------------------------------------
    // Developer Apps
    // -------------------------------------------------------------------------

    pub async fn list_apps(&self) -> Result<Vec<DeveloperApp>> {
        let url = format!("{}/developers/apps/?limit=100", self.base_url);
        let resp = self
            .client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        let paginated: Paginated<DeveloperApp> = resp.json().await.context("Failed to parse response")?;
        Ok(paginated.items)
    }

    pub async fn create_app(&self, req: &CreateAppRequest) -> Result<DeveloperAppCreated> {
        let url = format!("{}/developers/apps/", self.base_url);
        let resp = self
            .client
            .post(&url)
            .headers(self.auth_headers())
            .json(req)
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        resp.json().await.context("Failed to parse response")
    }

    // -------------------------------------------------------------------------
    // Community Servers
    // -------------------------------------------------------------------------

    pub async fn create_server(&self, app_id: &str, req: &CreateServerRequest) -> Result<ServerResponse> {
        let url = format!("{}/developers/apps/{}/servers/", self.base_url, app_id);
        let resp = self
            .client
            .post(&url)
            .headers(self.auth_headers())
            .json(req)
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        resp.json().await.context("Failed to parse response")
    }

    pub async fn list_servers(&self, app_id: &str) -> Result<Vec<ServerResponse>> {
        let url = format!("{}/developers/apps/{}/servers/?limit=100", self.base_url, app_id);
        let resp = self
            .client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        let paginated: Paginated<ServerResponse> = resp.json().await.context("Failed to parse response")?;
        Ok(paginated.items)
    }

    pub async fn delete_server(&self, app_id: &str, server_id: &str) -> Result<()> {
        let url = format!(
            "{}/developers/apps/{}/servers/{}/",
            self.base_url, app_id, server_id
        );
        let resp = self
            .client
            .delete(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        Ok(())
    }

    // -------------------------------------------------------------------------
    // Plugins
    // -------------------------------------------------------------------------

    pub async fn list_plugins(&self, app_id: &str) -> Result<Vec<PluginResponse>> {
        let url = format!("{}/developers/apps/{}/plugins/?limit=100", self.base_url, app_id);
        let resp = self
            .client
            .get(&url)
            .headers(self.auth_headers())
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        let paginated: Paginated<PluginResponse> = resp.json().await.context("Failed to parse response")?;
        Ok(paginated.items)
    }

    pub async fn list_public_plugins(&self) -> Result<Vec<PluginResponse>> {
        let url = format!("{}/plugins/?limit=100", self.base_url);
        let resp = self.client.get(&url).send().await.context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }

        let paginated: Paginated<serde_json::Value> =
            resp.json().await.context("Failed to parse response")?;
        let plugins = paginated
            .items
            .into_iter()
            .map(|v| PluginResponse {
                id: v["id"].as_str().unwrap_or("").to_string(),
                name: v["name"].as_str().unwrap_or("").to_string(),
                slug: v["slug"].as_str().unwrap_or("").to_string(),
                version: v["version"].as_str().unwrap_or("").to_string(),
                description: String::new(),
                is_published: true,
                is_approved: v["is_approved"].as_bool().unwrap_or(false),
                download_count: v["download_count"].as_u64().unwrap_or(0),
                created_at: String::new(),
            })
            .collect();
        Ok(plugins)
    }

    pub async fn create_plugin(&self, app_id: &str, req: &CreatePluginRequest) -> Result<PluginResponse> {
        let url = format!("{}/developers/apps/{}/plugins/", self.base_url, app_id);
        let resp = self
            .client
            .post(&url)
            .headers(self.auth_headers())
            .json(req)
            .send()
            .await
            .context("Network error")?;

        if !resp.status().is_success() {
            return Err(Self::handle_error(resp).await);
        }
        resp.json().await.context("Failed to parse response")
    }
}

/// Build an authed ApiClient from stored config. Errors if not logged in.
pub fn build_authed_client(api_url_override: &Option<String>) -> Result<ApiClient> {
    let cfg = crate::config::load()?;
    let auth = cfg.auth.as_ref().ok_or_else(|| {
        anyhow::anyhow!("Not authenticated. Run `zelqor login` first.")
    })?;
    let base_url = cfg.effective_api_url(api_url_override);
    Ok(ApiClient::new(&base_url, Some(&auth.access_token)))
}

/// Get the app_id from config, or bail with a helpful message.
pub fn require_app_id() -> Result<String> {
    let cfg = crate::config::load()?;
    cfg.auth
        .and_then(|a| a.app_id)
        .ok_or_else(|| anyhow::anyhow!("No app selected. Run `zelqor login` and select an app."))
}
