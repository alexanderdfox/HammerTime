//! Multi-port TCP listener with connection counting and SSH honeypot banner.

use crate::config::DefenderConfig;
use crate::defender::Hammer4DDefender;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::AsyncWriteExt;
use tokio::net::TcpListener;
use tokio::sync::watch;
use tokio::time::{interval, Duration};
use tracing::{debug, error, info, warn};

pub struct TcpListenerService {
    defender: Arc<Hammer4DDefender>,
    config: DefenderConfig,
}

impl TcpListenerService {
    pub fn new(defender: Arc<Hammer4DDefender>, config: DefenderConfig) -> Self {
        Self { defender, config }
    }

    pub async fn run(self, mut shutdown: watch::Receiver<bool>) -> anyhow::Result<()> {
        let mut listeners = Vec::new();
        let mut connection_counts: HashMap<u16, u64> = HashMap::new();

        for &port in &self.config.ports {
            match TcpListener::bind(("0.0.0.0", port)).await {
                Ok(listener) => {
                    info!("   ✅ Port {} is now LISTENING", port);
                    connection_counts.insert(port, 0);
                    listeners.push((port, listener));
                }
                Err(e) => {
                    error!("❌ Failed to bind port {}: {}", port, e);
                    // Continue with other ports
                }
            }
        }

        if listeners.is_empty() {
            anyhow::bail!("No ports could be bound");
        }

        info!("");
        info!("╔════════════════════════════════════════════════════════════════╗");
        info!("║  ✅ Defender is now ACTIVE and monitoring traffic             ║");
        info!("║  📡 Listening on configured ports                             ║");
        info!(
            "║  🌐 Timeline: {}",
            self.defender.reality_fork.current().as_str().to_uppercase()
        );
        info!("╚════════════════════════════════════════════════════════════════╝");
        info!("💡 Press Ctrl+C to stop gracefully");
        info!("");

        // Shared counters protected by a simple mutex for the timer
        let counts = Arc::new(tokio::sync::Mutex::new(connection_counts));
        let counts_for_timer = counts.clone();
        let defender_for_timer = self.defender.clone();

        // Per-second statistics timer
        let mut timer = interval(Duration::from_secs(1));
        let timer_task = tokio::spawn(async move {
            loop {
                timer.tick().await;
                if !defender_for_timer.is_running() {
                    break;
                }
                let mut map = counts_for_timer.lock().await;
                let total: u64 = map.values().sum();
                let per_port: Vec<String> = map
                    .iter()
                    .filter(|(_, &c)| c > 0)
                    .map(|(p, c)| format!("port {}: {}", p, c))
                    .collect();

                if total > 0 || true {
                    // Always report so the defender can track baseline
                    info!("");
                    info!("⏱️  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                    info!("📊 Connection Statistics (Last Second)");
                    info!("   🔢 Total: {} connections", total);
                    if !per_port.is_empty() {
                        info!("   📍 Per Port: {}", per_port.join(", "));
                    }
                    info!("⏱️  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                }

                defender_for_timer.analyze_traffic(total as u32);

                // Reset counters
                for v in map.values_mut() {
                    *v = 0;
                }
            }
        });

        // Accept loops
        let mut handles = Vec::new();
        for (port, listener) in listeners {
            let defender = self.defender.clone();
            let counts = counts.clone();
            let banner = self.config.ssh_banner.clone();
            let mut shutdown_rx = shutdown.clone();

            let handle = tokio::spawn(async move {
                loop {
                    tokio::select! {
                        _ = shutdown_rx.changed() => {
                            if *shutdown_rx.borrow() {
                                break;
                            }
                        }
                        accept = listener.accept() => {
                            match accept {
                                Ok((mut stream, addr)) => {
                                    let ip = addr.ip();
                                    defender.metrics.inc_connections();

                                    // Already blocked?
                                    if defender.is_blocked(ip) {
                                        defender.metrics.inc_blocked_conn();
                                        info!("⛔ BLOCKED CONNECTION ATTEMPT from {} → port {}", ip, port);
                                        let _ = stream.shutdown().await;
                                        continue;
                                    }

                                    // Per-IP rate limit
                                    if defender.record_and_check_rate(ip) {
                                        defender.block(ip, "per-IP rate limit exceeded");
                                        defender.metrics.inc_blocked_conn();
                                        let _ = stream.shutdown().await;
                                        continue;
                                    }

                                    // Count
                                    {
                                        let mut map = counts.lock().await;
                                        *map.entry(port).or_insert(0) += 1;
                                    }

                                    info!("🔗 New connection: {} → port {}", ip, port);

                                    // Honeypot: send SSH banner then close
                                    let banner_bytes = banner.as_bytes();
                                    if let Err(e) = stream.write_all(banner_bytes).await {
                                        debug!("Failed to send banner to {}: {}", ip, e);
                                    } else {
                                        info!("   🎭 Sent SSH-2.0 banner to {} (honeypot)", ip);
                                    }
                                    let _ = stream.shutdown().await;
                                }
                                Err(e) => {
                                    if defender.is_running() {
                                        warn!("Accept error on port {}: {}", port, e);
                                    }
                                }
                            }
                        }
                    }
                }
                debug!("Listener on port {} stopped", port);
            });
            handles.push(handle);
        }

        // Wait for shutdown signal
        let _ = shutdown.changed().await;
        info!("Stopping all listeners…");
        timer_task.abort();
        for h in handles {
            h.abort();
        }
        Ok(())
    }
}
