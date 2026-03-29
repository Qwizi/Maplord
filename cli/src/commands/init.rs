use anyhow::Result;
use dialoguer::Select;

use crate::commands::{plugin, server};
use crate::output;

pub async fn run(api_url_override: &Option<String>) -> Result<()> {
    output::header("Zelqor Project Init");

    let project_types = vec![
        "Community Server — Host a game server for players",
        "WASM Plugin    — Extend game logic with a custom plugin",
        "Cancel",
    ];

    let selection = Select::new()
        .with_prompt("What would you like to create?")
        .items(&project_types)
        .default(0)
        .interact()?;

    match selection {
        0 => {
            let args = server::ServerArgs {
                command: server::ServerCommand::Create,
            };
            server::run(&args, api_url_override).await
        }
        1 => {
            let args = plugin::PluginArgs {
                command: plugin::PluginCommand::Create,
            };
            plugin::run(&args, api_url_override).await
        }
        _ => {
            output::info("Init cancelled.");
            Ok(())
        }
    }
}
