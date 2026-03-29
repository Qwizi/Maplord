use anyhow::Result;
use console::style;
use std::process::Stdio;

use crate::output;

struct Check {
    name: &'static str,
    status: CheckStatus,
    detail: String,
}

enum CheckStatus {
    Ok,
    Warn,
    Fail,
}

impl CheckStatus {
    fn icon(&self) -> console::StyledObject<&'static str> {
        match self {
            CheckStatus::Ok => style("✓").green().bold(),
            CheckStatus::Warn => style("!").yellow().bold(),
            CheckStatus::Fail => style("✗").red().bold(),
        }
    }
}

pub async fn run() -> Result<()> {
    output::header("System Requirements Check");
    println!();

    let mut checks: Vec<Check> = Vec::new();

    // Docker
    checks.push(check_command("docker", &["--version"], "Docker").await);

    // Docker Compose
    checks.push(check_compose().await);

    // rustc
    checks.push(check_command("rustc", &["--version"], "Rust (rustc)").await);

    // cargo
    checks.push(check_command("cargo", &["--version"], "Cargo").await);

    // wasm32-wasip1 target
    checks.push(check_wasm_target().await);

    // which curl (optional, for healthchecks)
    checks.push(check_optional_command("curl", "curl (optional, for healthchecks)").await);

    // Print results
    let name_width = checks.iter().map(|c| c.name.len()).max().unwrap_or(0);
    for check in &checks {
        println!(
            "  {} {:<width$}  {}",
            check.status.icon(),
            check.name,
            style(&check.detail).dim(),
            width = name_width
        );
    }

    println!();

    let failed: Vec<_> = checks.iter().filter(|c| matches!(c.status, CheckStatus::Fail)).collect();
    let warned: Vec<_> = checks.iter().filter(|c| matches!(c.status, CheckStatus::Warn)).collect();

    if failed.is_empty() && warned.is_empty() {
        output::success("All checks passed. Your environment is ready.");
    } else {
        if !failed.is_empty() {
            output::error(&format!(
                "{} check(s) failed. Install the missing tools and re-run `zelqor doctor`.",
                failed.len()
            ));
        }
        if !warned.is_empty() {
            output::warn(&format!("{} warning(s). Some features may not work.", warned.len()));
        }
    }

    Ok(())
}

async fn check_command(cmd: &'static str, args: &[&str], name: &'static str) -> Check {
    match which::which(cmd) {
        Ok(path) => {
            // Get version string
            let version = get_version(cmd, args).await.unwrap_or_else(|| path.display().to_string());
            Check {
                name,
                status: CheckStatus::Ok,
                detail: version,
            }
        }
        Err(_) => Check {
            name,
            status: CheckStatus::Fail,
            detail: format!("not found — install {cmd}"),
        },
    }
}

async fn check_optional_command(cmd: &'static str, name: &'static str) -> Check {
    match which::which(cmd) {
        Ok(_) => {
            let version = get_version(cmd, &["--version"]).await.unwrap_or_default();
            Check {
                name,
                status: CheckStatus::Ok,
                detail: version,
            }
        }
        Err(_) => Check {
            name,
            status: CheckStatus::Warn,
            detail: format!("not found (optional)"),
        },
    }
}

async fn check_compose() -> Check {
    // Prefer `docker compose` (plugin) over `docker-compose` (standalone)
    let plugin = tokio::process::Command::new("docker")
        .args(["compose", "version"])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .await;

    match plugin {
        Ok(out) if out.status.success() => {
            let version = String::from_utf8_lossy(&out.stdout).trim().to_string();
            Check {
                name: "Docker Compose",
                status: CheckStatus::Ok,
                detail: version,
            }
        }
        _ => {
            // Fallback: standalone docker-compose
            match which::which("docker-compose") {
                Ok(_) => {
                    let version = get_version("docker-compose", &["--version"]).await.unwrap_or_default();
                    Check {
                        name: "Docker Compose",
                        status: CheckStatus::Warn,
                        detail: format!("{version} (standalone; consider upgrading to Docker Compose v2)"),
                    }
                }
                Err(_) => Check {
                    name: "Docker Compose",
                    status: CheckStatus::Fail,
                    detail: "not found — required for `zelqor server start`".to_string(),
                },
            }
        }
    }
}

async fn check_wasm_target() -> Check {
    let rustup = tokio::process::Command::new("rustup")
        .args(["target", "list", "--installed"])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .await;

    match rustup {
        Ok(out) => {
            let installed = String::from_utf8_lossy(&out.stdout);
            if installed.contains("wasm32-wasip1") {
                Check {
                    name: "wasm32-wasip1 target",
                    status: CheckStatus::Ok,
                    detail: "installed".to_string(),
                }
            } else {
                Check {
                    name: "wasm32-wasip1 target",
                    status: CheckStatus::Warn,
                    detail: "not installed — run `rustup target add wasm32-wasip1`".to_string(),
                }
            }
        }
        Err(_) => Check {
            name: "wasm32-wasip1 target",
            status: CheckStatus::Warn,
            detail: "rustup not found; cannot check WASM target".to_string(),
        },
    }
}

async fn get_version(cmd: &str, args: &[&str]) -> Option<String> {
    let out = tokio::process::Command::new(cmd)
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .ok()?;

    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();

    let combined = if !stdout.is_empty() { stdout } else { stderr };

    // Take only the first line to keep output compact
    Some(combined.lines().next().unwrap_or("").to_string())
}
