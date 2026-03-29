use clap::{Parser, Subcommand, ValueEnum};
use clap::builder::styling::{AnsiColor, Effects, Styles};

use crate::commands::{auth, doctor, init, plugin, server};

fn get_styles() -> Styles {
    Styles::styled()
        .header(AnsiColor::Cyan.on_default() | Effects::BOLD)
        .usage(AnsiColor::Cyan.on_default() | Effects::BOLD)
        .literal(AnsiColor::BrightCyan.on_default())
        .placeholder(AnsiColor::White.on_default())
        .error(AnsiColor::BrightRed.on_default() | Effects::BOLD)
        .valid(AnsiColor::BrightGreen.on_default())
        .invalid(AnsiColor::BrightRed.on_default())
}

#[derive(ValueEnum, Clone, Debug, Default)]
pub enum OutputFormat {
    #[default]
    Human,
    Json,
}

impl std::fmt::Display for OutputFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            OutputFormat::Human => write!(f, "human"),
            OutputFormat::Json => write!(f, "json"),
        }
    }
}

#[derive(Parser)]
#[command(
    name = "zelqor",
    about = "Zelqor game platform CLI",
    version,
    styles = get_styles(),
    propagate_version = true
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Command,

    /// API base URL (overrides config and ZELQOR_API_URL env var)
    #[arg(long, env = "ZELQOR_API_URL", global = true)]
    pub api_url: Option<String>,

    /// Output format
    #[arg(long, global = true, default_value = "human")]
    pub format: OutputFormat,
}

#[derive(Subcommand)]
pub enum Command {
    /// Authenticate with the Zelqor platform
    Login,
    /// Clear stored credentials
    Logout,
    /// Show current user info
    Whoami,
    /// Manage developer apps
    App(AppArgs),
    /// Manage community game servers
    Server(server::ServerArgs),
    /// Manage WASM plugins
    Plugin(plugin::PluginArgs),
    /// Initialize a new Zelqor project
    Init,
    /// Check system requirements
    Doctor,
}

#[derive(clap::Args)]
pub struct AppArgs {
    #[command(subcommand)]
    pub command: AppCommand,
}

#[derive(Subcommand)]
pub enum AppCommand {
    /// List your developer apps
    List,
    /// Create a new developer app
    Create,
}

impl Cli {
    pub async fn run(&self) -> anyhow::Result<()> {
        match &self.command {
            Command::Login => auth::login(&self.api_url).await,
            Command::Logout => auth::logout().await,
            Command::Whoami => auth::whoami(&self.api_url).await,
            Command::App(args) => match &args.command {
                AppCommand::List => server::list_apps(&self.api_url).await,
                AppCommand::Create => server::create_app(&self.api_url).await,
            },
            Command::Server(args) => server::run(args, &self.api_url).await,
            Command::Plugin(args) => plugin::run(args, &self.api_url).await,
            Command::Init => init::run(&self.api_url).await,
            Command::Doctor => doctor::run().await,
        }
    }
}
