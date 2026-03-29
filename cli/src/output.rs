use console::style;
use indicatif::{ProgressBar, ProgressStyle};
use std::time::Duration;
use tabled::{Table, Tabled};

pub fn success(msg: &str) {
    println!("{} {}", style("✓").green().bold(), msg);
}

pub fn error(msg: &str) {
    eprintln!("{} {}", style("✗").red().bold(), msg);
}

pub fn warn(msg: &str) {
    println!("{} {}", style("!").yellow().bold(), msg);
}

pub fn info(msg: &str) {
    println!("{} {}", style("→").cyan().bold(), msg);
}

pub fn header(msg: &str) {
    println!("\n{}", style(msg).bold().underlined());
}

pub fn spinner(msg: &str) -> ProgressBar {
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::with_template("{spinner:.cyan} {msg}")
            .unwrap()
            .tick_strings(&["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]),
    );
    pb.set_message(msg.to_string());
    pb.enable_steady_tick(Duration::from_millis(80));
    pb
}

pub fn print_table<T: Tabled>(items: Vec<T>) {
    if items.is_empty() {
        info("No items found.");
        return;
    }
    let table = Table::new(items).to_string();
    println!("{table}");
}

pub fn print_kv(pairs: &[(&str, String)]) {
    let key_width = pairs.iter().map(|(k, _)| k.len()).max().unwrap_or(0);
    for (key, value) in pairs {
        println!(
            "  {:<width$}  {}",
            style(*key).bold(),
            value,
            width = key_width
        );
    }
}

#[allow(dead_code)]
pub fn print_json<T: serde::Serialize>(value: &T) {
    match serde_json::to_string_pretty(value) {
        Ok(s) => println!("{s}"),
        Err(e) => error(&format!("Failed to serialize JSON: {e}")),
    }
}
