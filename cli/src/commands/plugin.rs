use anyhow::{bail, Context, Result};
use clap::Subcommand;
use console::style;
use dialoguer::{Confirm, Input, MultiSelect};
use sha2::{Digest, Sha256};
use std::fs;
use std::io::Read;
use std::path::PathBuf;
use std::process::Stdio;

use crate::api::client::ApiClient;
use crate::api::models::CreatePluginRequest;
use crate::config;
use crate::output;

#[derive(clap::Args)]
pub struct PluginArgs {
    #[command(subcommand)]
    pub command: PluginCommand,
}

#[derive(Subcommand)]
pub enum PluginCommand {
    /// Scaffold a new WASM plugin project
    Create,
    /// Build the WASM plugin (cargo build --target wasm32-wasip1 --release)
    Build,
    /// List your plugins (or public plugins with --public)
    List {
        /// Show public/approved plugins instead of your own
        #[arg(long)]
        public: bool,
    },
    /// Register plugin metadata with the platform
    Publish,
}

static AVAILABLE_HOOKS: &[&str] = &[
    "on_tick",
    "on_player_action",
    "on_combat_resolve",
    "on_match_start",
    "on_match_end",
    "on_player_join",
    "on_player_leave",
    "on_economy_tick",
];

pub async fn run(args: &PluginArgs, api_url_override: &Option<String>) -> Result<()> {
    match &args.command {
        PluginCommand::Create => create_plugin_scaffold(api_url_override).await,
        PluginCommand::Build => build_plugin().await,
        PluginCommand::List { public } => list_plugins(api_url_override, *public).await,
        PluginCommand::Publish => publish_plugin(api_url_override).await,
    }
}

async fn create_plugin_scaffold(api_url_override: &Option<String>) -> Result<()> {
    output::header("Create Zelqor WASM Plugin");

    let name: String = Input::new()
        .with_prompt("Plugin name (e.g. my-plugin)")
        .interact_text()?;

    let slug: String = Input::new()
        .with_prompt("Slug (lowercase-hyphen, e.g. my-plugin)")
        .default(name.to_lowercase().replace(' ', "-"))
        .interact_text()?;

    let description: String = Input::new()
        .with_prompt("Description")
        .default(String::new())
        .allow_empty(true)
        .interact_text()?;

    let hook_selections = MultiSelect::new()
        .with_prompt("Select hooks to implement (space to toggle, enter to confirm)")
        .items(AVAILABLE_HOOKS)
        .interact()?;

    let hooks: Vec<String> = hook_selections
        .into_iter()
        .map(|i| AVAILABLE_HOOKS[i].to_string())
        .collect();

    // Scaffold directory
    let dir = PathBuf::from(&slug);
    if dir.exists() {
        bail!("Directory '{}' already exists.", slug);
    }
    let src_dir = dir.join("src");
    fs::create_dir_all(&src_dir).context("Failed to create plugin directory")?;

    // Cargo.toml
    let cargo_toml = generate_plugin_cargo_toml(&name, &slug);
    fs::write(dir.join("Cargo.toml"), cargo_toml)?;

    // src/lib.rs
    let lib_rs = generate_plugin_lib_rs(&hooks);
    fs::write(src_dir.join("lib.rs"), lib_rs)?;

    // .cargo/config.toml for wasm target
    let cargo_config_dir = dir.join(".cargo");
    fs::create_dir_all(&cargo_config_dir)?;
    fs::write(
        cargo_config_dir.join("config.toml"),
        "[build]\ntarget = \"wasm32-wasip1\"\n",
    )?;

    // zelqor-plugin.toml manifest
    let manifest = generate_plugin_manifest(&name, &slug, &description, &hooks);
    fs::write(dir.join("zelqor-plugin.toml"), manifest)?;

    // README
    fs::write(
        dir.join("README.md"),
        format!(
            "# {name}\n\n{description}\n\n## Building\n\n```bash\nzelqor plugin build\n```\n"
        ),
    )?;

    output::success(&format!("Plugin scaffolded at ./{slug}"));
    println!();
    println!("  Next steps:");
    println!("    {} cd {}", style("1.").cyan(), slug);
    println!("    {} Edit {}", style("2.").cyan(), style("src/lib.rs").bold());
    println!(
        "    {} Run {}",
        style("3.").cyan(),
        style("zelqor plugin build").bold()
    );
    println!(
        "    {} Run {}",
        style("4.").cyan(),
        style("zelqor plugin publish").bold()
    );

    // Optionally register with platform now
    let register = Confirm::new()
        .with_prompt("Register this plugin with the platform now?")
        .default(false)
        .interact()?;

    if register {
        register_plugin_with_platform(api_url_override, &name, &slug, &description, &hooks).await?;
    }

    Ok(())
}

async fn register_plugin_with_platform(
    api_url_override: &Option<String>,
    name: &str,
    slug: &str,
    description: &str,
    hooks: &[String],
) -> Result<()> {
    let cfg = config::load()?;
    let auth = cfg
        .auth
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("Not authenticated. Run `zelqor login` first."))?;
    let app_id = auth
        .app_id
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No active app. Run `zelqor app create` first."))?;
    let base_url = cfg.effective_api_url(api_url_override);
    let client = ApiClient::new(&base_url, Some(&auth.access_token));

    let sp = output::spinner("Registering plugin...");
    let result = client
        .create_plugin(
            &app_id,
            &CreatePluginRequest {
                name: name.to_string(),
                slug: slug.to_string(),
                description: description.to_string(),
                hooks: hooks.to_vec(),
            },
        )
        .await;
    sp.finish_and_clear();

    match result {
        Ok(plugin) => {
            output::success(&format!("Plugin '{}' registered (ID: {})", plugin.name, &plugin.id[..8]));
        }
        Err(e) => {
            output::warn(&format!("Could not register plugin: {}", e));
        }
    }
    Ok(())
}

async fn build_plugin() -> Result<()> {
    output::header("Build WASM Plugin");

    // Check for zelqor-plugin.toml
    if !std::path::Path::new("zelqor-plugin.toml").exists() {
        bail!("zelqor-plugin.toml not found. Are you in a plugin directory?");
    }

    // Ensure wasm32-wasip1 target is installed
    let sp = output::spinner("Checking wasm32-wasip1 target...");
    let target_check = tokio::process::Command::new("rustup")
        .args(["target", "list", "--installed"])
        .output()
        .await
        .context("Failed to run rustup")?;
    sp.finish_and_clear();

    let installed = String::from_utf8_lossy(&target_check.stdout);
    if !installed.contains("wasm32-wasip1") {
        output::warn("wasm32-wasip1 target not installed. Installing...");
        let status = tokio::process::Command::new("rustup")
            .args(["target", "add", "wasm32-wasip1"])
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status()
            .await
            .context("Failed to run rustup target add")?;
        if !status.success() {
            bail!("Failed to install wasm32-wasip1 target");
        }
    }

    let sp = output::spinner("Compiling WASM plugin (release)...");
    let status = tokio::process::Command::new("cargo")
        .args(["build", "--target", "wasm32-wasip1", "--release"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .status()
        .await
        .context("Failed to run cargo build")?;
    sp.finish_and_clear();

    if !status.success() {
        bail!("cargo build failed. Run `cargo build --target wasm32-wasip1 --release` for details.");
    }

    // Find the .wasm output
    let wasm_files: Vec<_> = glob_wasm_outputs()?;
    if wasm_files.is_empty() {
        bail!("No .wasm output files found in target/wasm32-wasip1/release/");
    }

    for wasm_path in &wasm_files {
        let hash = sha256_file(wasm_path)?;
        let size = fs::metadata(wasm_path)?.len();
        output::success(&format!(
            "Built: {} ({} KB)",
            wasm_path.display(),
            size / 1024
        ));
        output::print_kv(&[("SHA-256", hash)]);
    }

    Ok(())
}

fn glob_wasm_outputs() -> Result<Vec<PathBuf>> {
    let base = PathBuf::from("target/wasm32-wasip1/release");
    if !base.exists() {
        return Ok(vec![]);
    }
    let mut results = vec![];
    for entry in fs::read_dir(&base).context("Failed to read target dir")? {
        let entry = entry?;
        let path = entry.path();
        if path.extension().map(|e| e == "wasm").unwrap_or(false) {
            results.push(path);
        }
    }
    Ok(results)
}

fn sha256_file(path: &PathBuf) -> Result<String> {
    let mut file = fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 65536];
    loop {
        let n = file.read(&mut buf)?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(hex::encode(hasher.finalize()))
}

async fn list_plugins(api_url_override: &Option<String>, public: bool) -> Result<()> {
    let cfg = config::load()?;
    let base_url = cfg.effective_api_url(api_url_override);

    if public {
        let client = ApiClient::new(&base_url, None);
        let sp = output::spinner("Fetching public plugins...");
        let plugins = client.list_public_plugins().await;
        sp.finish_and_clear();

        let plugins = plugins?;
        output::header(&format!("Public Plugins ({})", plugins.len()));
        output::print_table(plugins);
    } else {
        let auth = cfg
            .auth
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("Not authenticated. Run `zelqor login` first."))?;
        let app_id = auth
            .app_id
            .clone()
            .ok_or_else(|| anyhow::anyhow!("No active app. Run `zelqor app create` first."))?;
        let client = ApiClient::new(&base_url, Some(&auth.access_token));

        let sp = output::spinner("Fetching plugins...");
        let plugins = client.list_plugins(&app_id).await;
        sp.finish_and_clear();

        let plugins = plugins?;
        output::header(&format!("Your Plugins ({})", plugins.len()));
        output::print_table(plugins);
    }

    Ok(())
}

async fn publish_plugin(api_url_override: &Option<String>) -> Result<()> {
    output::header("Publish Plugin");

    // Read manifest
    let manifest_path = "zelqor-plugin.toml";
    if !std::path::Path::new(manifest_path).exists() {
        bail!("zelqor-plugin.toml not found. Are you in a plugin directory?");
    }

    let manifest_str = fs::read_to_string(manifest_path)?;
    let manifest: toml::Value = toml::from_str(&manifest_str)?;

    let name = manifest["name"].as_str().unwrap_or("").to_string();
    let slug = manifest["slug"].as_str().unwrap_or("").to_string();
    let description = manifest.get("description").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let hooks: Vec<String> = manifest
        .get("hooks")
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default();

    // Show summary
    output::print_kv(&[
        ("Name", name.clone()),
        ("Slug", slug.clone()),
        ("Description", description.clone()),
        ("Hooks", hooks.join(", ")),
    ]);
    println!();

    let confirm = Confirm::new()
        .with_prompt("Publish this plugin to the platform?")
        .default(true)
        .interact()?;

    if !confirm {
        output::info("Publish cancelled.");
        return Ok(());
    }

    register_plugin_with_platform(api_url_override, &name, &slug, &description, &hooks).await?;
    output::info("Your plugin is pending review before appearing in the public listing.");
    Ok(())
}

fn generate_plugin_cargo_toml(name: &str, slug: &str) -> String {
    format!(
        r#"[package]
name = "{slug}"
version = "0.1.0"
edition = "2021"
description = "{name} — Zelqor WASM plugin"

[lib]
crate-type = ["cdylib"]

[dependencies]
# Add your dependencies here
"#
    )
}

fn generate_plugin_lib_rs(hooks: &[String]) -> String {
    let mut code = String::from(
        r#"//! Zelqor WASM Plugin
//! Generated by `zelqor plugin create`

// ============================================================
// Hook implementations
// Each hook is exported as a C ABI function that the Zelqor
// gateway calls at the appropriate point in game logic.
// ============================================================

"#,
    );

    for hook in hooks {
        let fn_body = match hook.as_str() {
            "on_tick" => "    // Called every game tick. Implement tick-level logic here.\n    0",
            "on_player_action" => "    // Called when a player performs an action.\n    0",
            "on_combat_resolve" => "    // Called when combat is being resolved.\n    0",
            "on_match_start" => "    // Called when a match begins.\n    0",
            "on_match_end" => "    // Called when a match ends.\n    0",
            "on_player_join" => "    // Called when a player joins the match.\n    0",
            "on_player_leave" => "    // Called when a player leaves the match.\n    0",
            "on_economy_tick" => "    // Called on each economy tick.\n    0",
            _ => "    0",
        };
        code.push_str(&format!(
            r#"/// Hook: {hook}
#[no_mangle]
pub extern "C" fn {hook}(ctx_ptr: u32, ctx_len: u32) -> i32 {{
{fn_body}
}}

"#
        ));
    }

    code
}

fn generate_plugin_manifest(name: &str, slug: &str, description: &str, hooks: &[String]) -> String {
    let hooks_toml: String = hooks
        .iter()
        .map(|h| format!("  \"{h}\""))
        .collect::<Vec<_>>()
        .join(",\n");

    format!(
        r#"# Zelqor Plugin Manifest
name = "{name}"
slug = "{slug}"
description = "{description}"
version = "0.1.0"

hooks = [
{hooks_toml}
]
"#
    )
}
