use anyhow::{bail, Result};
use console::style;
use dialoguer::{Input, Select};
use tokio::io::AsyncWriteExt;
use tokio::net::TcpListener;

use crate::api::client::ApiClient;
use crate::config::{self, AuthConfig};
use crate::output;

/// OAuth login flow:
/// 1. User provides client_id and client_secret (from their DeveloperApp)
/// 2. CLI starts a local HTTP server on a random port
/// 3. Opens browser to the authorization page with redirect_uri=http://localhost:{port}/callback
/// 4. User logs in and authorizes
/// 5. CLI receives the authorization code via the callback
/// 6. CLI exchanges the code for access + refresh tokens
pub async fn login(api_url_override: &Option<String>) -> Result<()> {
    output::header("Zelqor Login");

    let cfg = config::load()?;
    let base_url = cfg.effective_api_url(api_url_override);
    let frontend_url = cfg.effective_frontend_url();

    println!();
    println!(
        "  {} You need a Developer App to authenticate.",
        style("Info:").cyan()
    );
    println!(
        "  {} Create one at {}/developers",
        style("    ").cyan(),
        frontend_url
    );
    println!();

    let client_id: String = Input::new()
        .with_prompt("Client ID (from your Developer App)")
        .interact_text()?;
    let client_id = client_id.trim().to_string();
    if client_id.is_empty() {
        bail!("Client ID cannot be empty.");
    }

    let client_secret: String = Input::new()
        .with_prompt("Client Secret")
        .interact_text()?;
    let client_secret = client_secret.trim().to_string();
    if client_secret.is_empty() {
        bail!("Client Secret cannot be empty.");
    }

    // Start local callback server
    let listener = TcpListener::bind("127.0.0.1:0").await?;
    let port = listener.local_addr()?.port();
    let redirect_uri = format!("http://localhost:{port}/callback");

    // Build authorization URL
    let auth_url = format!(
        "{}/oauth/authorize?client_id={}&redirect_uri={}&response_type=code&scope=user:profile",
        frontend_url,
        urlencoding::encode(&client_id),
        urlencoding::encode(&redirect_uri),
    );

    output::info(&format!("Opening browser to authorize..."));
    println!();
    println!("  {}", style(&auth_url).dim().underlined());
    println!();

    // Try to open browser
    if open::that(&auth_url).is_err() {
        output::warn("Could not open browser. Please open the URL above manually.");
    }

    output::info("Waiting for authorization callback...");

    // Wait for the callback with the authorization code
    let code = wait_for_callback(listener).await?;

    // Exchange code for tokens
    let sp = output::spinner("Exchanging authorization code for tokens...");
    let token_resp = ApiClient::exchange_code(
        &base_url,
        &client_id,
        &client_secret,
        &code,
        &redirect_uri,
    )
    .await;
    sp.finish_and_clear();

    let token_resp = match token_resp {
        Ok(t) => t,
        Err(e) => bail!("Token exchange failed: {}", e),
    };

    // Validate the token works
    let sp = output::spinner("Validating session...");
    let client = ApiClient::new(&base_url, Some(&token_resp.access_token));
    let apps = client.list_apps().await.unwrap_or_default();
    sp.finish_and_clear();

    // Optionally select an app
    let app_id = if !apps.is_empty() {
        let mut choices: Vec<String> = apps
            .iter()
            .map(|a| format!("{} ({})", a.name, &a.id[..8]))
            .collect();
        choices.push("Skip".to_string());
        let idx = Select::new()
            .with_prompt("Associate with a developer app?")
            .items(&choices)
            .default(0)
            .interact()?;
        if idx < apps.len() {
            Some(apps[idx].id.clone())
        } else {
            None
        }
    } else {
        None
    };

    // Save config
    let mut cfg = config::load()?;
    cfg.auth = Some(AuthConfig {
        access_token: token_resp.access_token,
        refresh_token: token_resp.refresh_token,
        client_id,
        client_secret,
        app_id,
    });
    if let Some(url) = api_url_override {
        cfg.api_url = Some(url.clone());
    }
    config::save(&cfg)?;

    output::success("Authenticated successfully!");
    if let Some(path) = config::config_path().ok() {
        output::info(&format!("Config saved to {}", path.display()));
    }
    Ok(())
}

/// Wait for the OAuth callback on the local TCP listener.
/// Parses the `code` query parameter from the request.
async fn wait_for_callback(listener: TcpListener) -> Result<String> {
    let (mut stream, _) = listener.accept().await?;

    // Read the HTTP request
    let mut buf = vec![0u8; 4096];
    let n = tokio::io::AsyncReadExt::read(&mut stream, &mut buf).await?;
    let request = String::from_utf8_lossy(&buf[..n]);

    // Parse the GET request line for the code parameter
    let first_line = request.lines().next().unwrap_or("");
    let path = first_line.split_whitespace().nth(1).unwrap_or("");

    let code = url_param(path, "code");

    // Send a nice HTML response
    let (status, body) = if code.is_some() {
        (
            "200 OK",
            "<html><body style='font-family:system-ui;text-align:center;padding:60px'>\
             <h1 style='color:#22d3ee'>&#10003; Authorized!</h1>\
             <p>You can close this tab and return to the terminal.</p>\
             </body></html>",
        )
    } else {
        (
            "400 Bad Request",
            "<html><body style='font-family:system-ui;text-align:center;padding:60px'>\
             <h1 style='color:#ef4444'>Authorization Failed</h1>\
             <p>No authorization code received. Please try again.</p>\
             </body></html>",
        )
    };

    let response = format!(
        "HTTP/1.1 {status}\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n{body}"
    );
    stream.write_all(response.as_bytes()).await?;
    stream.shutdown().await?;

    code.ok_or_else(|| anyhow::anyhow!("No authorization code received in callback"))
}

/// Extract a query parameter from a URL path like /callback?code=abc&state=xyz
fn url_param(path: &str, key: &str) -> Option<String> {
    let query = path.split('?').nth(1)?;
    for pair in query.split('&') {
        let mut parts = pair.splitn(2, '=');
        if parts.next()? == key {
            return parts.next().map(|v| urlencoding::decode(v).unwrap_or_default().into_owned());
        }
    }
    None
}

pub async fn logout() -> Result<()> {
    let mut cfg = config::load()?;
    if cfg.auth.is_none() {
        output::warn("You are not currently logged in.");
        return Ok(());
    }
    cfg.auth = None;
    config::save(&cfg)?;
    output::success("Logged out. Credentials removed.");
    Ok(())
}

pub async fn whoami(api_url_override: &Option<String>) -> Result<()> {
    let cfg = config::load()?;

    let auth = cfg.auth.as_ref().ok_or_else(|| {
        anyhow::anyhow!("Not authenticated. Run `zelqor login` first.")
    })?;

    let base_url = cfg.effective_api_url(api_url_override);
    let client = ApiClient::new(&base_url, Some(&auth.access_token));

    let sp = output::spinner("Fetching account info...");
    let apps = client.list_apps().await;
    sp.finish_and_clear();

    output::header("Current Session");
    output::print_kv(&[
        ("API URL", base_url),
        ("Client ID", auth.client_id.clone()),
        (
            "App ID",
            auth.app_id
                .clone()
                .unwrap_or_else(|| "(none)".to_string()),
        ),
        (
            "Refresh Token",
            if auth.refresh_token.is_some() {
                "present".to_string()
            } else {
                "none".to_string()
            },
        ),
    ]);

    match apps {
        Ok(apps) => {
            println!();
            output::header(&format!("Developer Apps ({})", apps.len()));
            for app in &apps {
                println!(
                    "  {} {} {}",
                    style(&app.name).bold(),
                    style(format!("({})", &app.id[..8])).dim(),
                    if app.is_active {
                        style("active").green().to_string()
                    } else {
                        style("inactive").red().to_string()
                    }
                );
            }
        }
        Err(e) => {
            output::warn(&format!("Could not fetch apps: {}", e));
        }
    }

    Ok(())
}
