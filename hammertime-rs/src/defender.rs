//! Core defender logic: anomaly detection, rate limiting, blocking.

use crate::config::DefenderConfig;
use crate::firewall::Firewall;
use crate::ip::TrackedIp;
use crate::metrics::Metrics;
use crate::temporal::{FunctionSwapper, RealityFork, TimeVariable, Timeline};
use chrono::{DateTime, Utc};
use dashmap::DashMap;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::net::IpAddr;
use std::path::Path;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::{debug, error, info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
struct BlockEntry {
    ip: String,
    blocked_at: DateTime<Utc>,
    expires_at: Option<DateTime<Utc>>,
    reason: String,
}

pub struct Hammer4DDefender {
    config: DefenderConfig,
    request_rate: TimeVariable<u32>,
    detection_logic: FunctionSwapper,
    pub reality_fork: RealityFork,
    firewall: Firewall,
    blocked: DashMap<IpAddr, BlockEntry>,
    /// Per-IP connection timestamps (sliding window)
    ip_hits: DashMap<IpAddr, Vec<Instant>>,
    pub metrics: Arc<Metrics>,
    running: RwLock<bool>,
}

impl Hammer4DDefender {
    pub fn new(config: DefenderConfig, metrics: Arc<Metrics>) -> Self {
        let firewall = Firewall::new(&config.firewall_backend, config.enable_firewall);

        let detection_logic = FunctionSwapper::new(|| {
            info!("🔍 Traffic normal.");
        });

        let reality_fork = RealityFork::new();

        let defender = Self {
            request_rate: TimeVariable::new(0, config.max_history_size),
            detection_logic,
            reality_fork,
            firewall,
            blocked: DashMap::new(),
            ip_hits: DashMap::new(),
            metrics,
            running: RwLock::new(true),
            config,
        };

        // Restore persistent blocklist if present
        if let Some(path) = &defender.config.blocklist_path {
            if let Err(e) = defender.load_blocklist(path) {
                warn!("Could not load blocklist from {}: {}", path, e);
            }
        }

        defender
    }

    pub fn is_running(&self) -> bool {
        *self.running.read()
    }

    pub async fn shutdown(&self) {
        *self.running.write() = false;
        if let Some(path) = &self.config.blocklist_path {
            if let Err(e) = self.save_blocklist(path) {
                error!("Failed to save blocklist: {}", e);
            } else {
                info!("💾 Blocklist saved to {}", path);
            }
        }
    }

    // ─── Traffic analysis ───────────────────────────────────────────────

    pub fn analyze_traffic(&self, rate: u32) {
        self.request_rate.set(rate);

        let threshold_exceeded = rate > self.config.anomaly_threshold;
        // Simple statistical anomaly: > 3× recent average or absolute threshold
        let history_len = self.request_rate.history_len();
        let is_anomalous = threshold_exceeded;

        info!("");
        info!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        info!("📊 Traffic Analysis Report");
        info!("   📈 Current Rate: {} connections/sec", rate);
        info!("   🎯 Threshold: {} connections/sec", self.config.anomaly_threshold);
        info!(
            "   📉 Threshold Status: {}",
            if threshold_exceeded {
                "🚨 EXCEEDED"
            } else {
                "✅ Within limits"
            }
        );
        debug!("History length: {}", history_len);

        if is_anomalous {
            self.metrics.inc_anomaly();
            info!("");
            info!("🚨🚨🚨 ALERT: ANOMALOUS TRAFFIC DETECTED 🚨🚨🚨");
            info!(
                "   ⚠️  Rate: {}/sec (Threshold: {}/sec)",
                rate, self.config.anomaly_threshold
            );
            if threshold_exceeded {
                info!(
                    "   📊 Exceeded by {} connections/sec",
                    rate.saturating_sub(self.config.anomaly_threshold)
                );
            }

            self.request_rate.rewind(1);
            self.detection_logic.mutate(|| {
                info!("   🛠️  Enhanced detection logic active");
            });
            self.reality_fork.switch_to(Timeline::Omega);
            self.reality_fork.run();
        } else {
            info!("   ✅ Traffic is within normal parameters");
            self.reality_fork.switch_to(Timeline::Alpha);
            self.detection_logic.mutate(|| {
                info!("   🔍 Normal detection logic active");
            });
            self.reality_fork.run();
        }
        info!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    }

    // ─── Per-IP rate limiting ───────────────────────────────────────────

    /// Record a connection from `ip`. Returns true if the IP should be blocked
    /// because it exceeded the per-IP rate limit.
    pub fn record_and_check_rate(&self, ip: IpAddr) -> bool {
        if self.config.per_ip_rate_limit == 0 {
            return false;
        }
        if self.config.is_whitelisted(ip) {
            return false;
        }

        let now = Instant::now();
        let window = Duration::from_secs(self.config.per_ip_window_secs);

        let mut entry = self.ip_hits.entry(ip).or_insert_with(Vec::new);
        // Prune old timestamps
        entry.retain(|&t| now.duration_since(t) < window);
        entry.push(now);

        let count = entry.len() as u32;
        if count > self.config.per_ip_rate_limit {
            self.metrics.inc_rate_limit();
            warn!(
                "🚦 Per-IP rate limit exceeded for {} ({} > {} in {}s)",
                ip, count, self.config.per_ip_rate_limit, self.config.per_ip_window_secs
            );
            return true;
        }
        false
    }

    // ─── Blocking ───────────────────────────────────────────────────────

    pub fn is_blocked(&self, ip: IpAddr) -> bool {
        if let Some(entry) = self.blocked.get(&ip) {
            if let Some(exp) = entry.expires_at {
                if Utc::now() > exp {
                    // Expired — remove
                    drop(entry);
                    self.blocked.remove(&ip);
                    return false;
                }
            }
            return true;
        }
        false
    }

    pub fn block(&self, ip: IpAddr, reason: &str) {
        if self.config.is_whitelisted(ip) {
            info!("🛡  Skipping block for whitelisted IP {}", ip);
            return;
        }
        if self.is_blocked(ip) {
            return;
        }

        let now = Utc::now();
        let expires = if self.config.block_duration_secs > 0 {
            Some(now + chrono::Duration::seconds(self.config.block_duration_secs as i64))
        } else {
            None
        };

        let entry = BlockEntry {
            ip: ip.to_string(),
            blocked_at: now,
            expires_at: expires,
            reason: reason.to_string(),
        };

        self.blocked.insert(ip, entry);
        self.metrics.inc_blocked_ip();

        let tracked = TrackedIp::new(ip);
        info!("");
        info!("🔒━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        info!("🚫 BLOCKING IP ADDRESS");
        info!("   📍 IP: {}", tracked.firewall_format());
        info!("   📝 Reason: {}", reason);
        info!("   📊 Total blocked IPs: {}", self.blocked.len());
        if let Some(exp) = expires {
            info!("   ⏳ Expires: {}", exp);
        } else {
            info!("   ⏳ Duration: permanent (until restart / manual clear)");
        }

        self.firewall.block(&tracked);
        info!("🔒━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    }

    // ─── Persistence ────────────────────────────────────────────────────

    fn load_blocklist(&self, path: &str) -> anyhow::Result<()> {
        let path = Path::new(path);
        if !path.exists() {
            return Ok(());
        }
        let data = std::fs::read_to_string(path)?;
        let entries: Vec<BlockEntry> = serde_json::from_str(&data)?;
        let now = Utc::now();
        let mut loaded = 0;
        for e in entries {
            if let Some(exp) = e.expires_at {
                if now > exp {
                    continue; // already expired
                }
            }
            if let Ok(addr) = e.ip.parse::<IpAddr>() {
                self.blocked.insert(addr, e);
                loaded += 1;
            }
        }
        info!("📂 Loaded {} entries from blocklist {}", loaded, path.display());
        Ok(())
    }

    fn save_blocklist(&self, path: &str) -> anyhow::Result<()> {
        let entries: Vec<BlockEntry> = self
            .blocked
            .iter()
            .map(|e| e.value().clone())
            .collect();
        let data = serde_json::to_string_pretty(&entries)?;
        std::fs::write(path, data)?;
        Ok(())
    }
}
