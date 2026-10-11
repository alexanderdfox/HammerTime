//! HammerTime — Rust rewrite of the Swift Hammer4D Defender
//!
//! Real-time TCP traffic defender with anomaly detection,
//! adaptive logic mutation, multi-timeline execution, per-IP rate limiting,
//! whitelist/CIDR support, and cross-platform firewall integration.

mod config;
mod defender;
mod firewall;
mod ip;
mod listener;
mod metrics;
mod temporal;

use clap::Parser;
use std::path::PathBuf;
use std::sync::Arc;
use tracing::{error, info, Level};
use tracing_subscriber::EnvFilter;

use crate::config::DefenderConfig;
use crate::defender::Hammer4DDefender;
use crate::listener::TcpListenerService;
use crate::metrics::Metrics;

#[derive(Parser, Debug)]
#[command(
    name = "hammertime",
    about = "🛡️  HammerTime — Real-time TCP traffic defender with anomaly detection",
    version,
    author
)]
struct Cli {
    /// Path to TOML configuration file
    #[arg(short, long, env = "HAMMERTIME_CONFIG", default_value = "config/hammertime.toml")]
    config: PathBuf,

    /// Enable debug mode (disables real firewall actions)
    #[arg(short, long, env = "DEBUG")]
    debug: bool,

    /// Verbose logging
    #[arg(short, long, env = "VERBOSE")]
    verbose: bool,

    /// Log in JSON format
    #[arg(long)]
    json: bool,

    /// Override anomaly threshold (connections/sec)
    #[arg(long)]
    threshold: Option<u32>,

    /// Override ports (comma-separated)
    #[arg(long, value_delimiter = ',')]
    ports: Option<Vec<u16>>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Logging setup
    let filter = if cli.verbose || cli.debug {
        EnvFilter::new("hammertime=debug,info")
    } else {
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"))
    };

    if cli.json {
        tracing_subscriber::fmt()
            .json()
            .with_env_filter(filter)
            .with_target(false)
            .init();
    } else {
        tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_target(false)
            .with_max_level(if cli.debug { Level::DEBUG } else { Level::INFO })
            .init();
    }

    banner(cli.debug, cli.verbose);

    // Load configuration
    let mut config = DefenderConfig::load(&cli.config).unwrap_or_else(|e| {
        tracing::warn!("Could not load config from {:?}: {}. Using defaults.", cli.config, e);
        DefenderConfig::default()
    });

    if cli.debug {
        config.debug_mode = true;
        config.enable_firewall = false;
        info!("🐛 Debug mode: firewall actions disabled for safety");
    }
    if let Some(t) = cli.threshold {
        config.anomaly_threshold = t;
    }
    if let Some(ports) = cli.ports {
        config.ports = ports;
    }

    config.log_summary();

    let metrics = Arc::new(Metrics::new());
    let defender = Arc::new(Hammer4DDefender::new(config.clone(), metrics.clone()));

    // Graceful shutdown
    let (shutdown_tx, mut shutdown_rx) = tokio::sync::watch::channel(false);
    let defender_for_shutdown = defender.clone();

    ctrlc::set_handler(move || {
        info!("🛑 Shutdown signal received — initiating graceful stop");
        let _ = shutdown_tx.send(true);
    })?;

    let listener = TcpListenerService::new(defender.clone(), config.clone());
    let shutdown_rx_for_listener = shutdown_rx.clone();
    let listener_handle = tokio::spawn(async move {
        if let Err(e) = listener.run(shutdown_rx_for_listener).await {
            error!("Listener error: {:#}", e);
        }
    });

    // Wait for shutdown
    let _ = shutdown_rx.changed().await;
    info!("Cleaning up…");
    defender_for_shutdown.shutdown().await;
    listener_handle.abort();

    metrics.print_summary();
    info!("✅ Defender shutdown complete");
    Ok(())
}

fn banner(debug: bool, verbose: bool) {
    info!("╔════════════════════════════════════════════════════════════════╗");
    info!("║  🛡️  HammerTime (Rust) — Advanced DDoS Protection             ║");
    if debug {
        info!("║  🐛 DEBUG MODE ENABLED                                        ║");
    }
    if verbose {
        info!("║  🔍 VERBOSE MODE ENABLED                                      ║");
    }
    info!("╚════════════════════════════════════════════════════════════════╝");
}
