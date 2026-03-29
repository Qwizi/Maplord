mod api;
mod cli;
mod commands;
mod config;
mod output;

use clap::Parser;

#[tokio::main]
async fn main() {
    let cli = cli::Cli::parse();
    if let Err(e) = cli.run().await {
        output::error(&e.to_string());
        std::process::exit(1);
    }
}
