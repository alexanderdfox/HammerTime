//! Configuration loading and defaults.

use ipnet::IpNet;
use serde::{Deserialize, Serialize};
use std::fs;
use std::net::IpAddr;
use std::path::Path;
use tracing::info;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefenderConfig {
    /// TCP ports to listen on (honeypot / monitoring)
    #[serde(default = "default_ports")]
    pub ports: Vec<u16>,

    /// Global connections-per-second threshold that triggers anomaly response
    #[serde(default = "default_threshold")]
    pub anomaly_threshold: u32,

    /// Maximum history size for TimeVariable
    #[serde(default = "default_history")]
    pub max_history_size: usize,

    /// Whether to apply real firewall rules
    #[serde(default = "default_true")]
    pub enable_firewall: bool,

    /// Firewall backend: "auto", "iptables", "nftables", "pf", "none"
    #[serde(default = "default_firewall_backend")]
    pub firewall_backend: String,

    /// Path to optional persistent blocklist JSON
    #[serde(default)]
    pub blocklist_path: Option<String>,

    /// Per-IP rate limit (connections per second). 0 = disabled
    #[serde(default = "default_per_ip_limit")]
    pub per_ip_rate_limit: u32,

    /// Window in seconds for per-IP rate calculation
    #[serde(default = "default_rate_window")]
    pub per_ip_window_secs: u64,

    /// Temporary block duration in seconds (0 = permanent until restart)
    #[serde(default = "default_block_duration")]
    pub block_duration_secs: u64,

    /// IPs or CIDRs that must never be blocked
    #[serde(default)]
    pub whitelist: Vec<String>,

    /// Debug mode (disables firewall, extra logging)
    #[serde(default)]
    pub debug_mode: bool,

    /// SSH banner to send as honeypot response
    #[serde(default = "default_banner")]
    pub ssh_banner: String,
}

fn default_ports() -> Vec<u16> {
    vec![22, 80, 443, 2222]
}
fn default_threshold() -> u32 {
    200
}
fn default_history() -> usize {
    1000
}
fn default_true() -> bool {
    true
}
fn default_firewall_backend() -> String {
    "auto".into()
}
fn default_per_ip_limit() -> u32 {
    15
}
fn default_rate_window() -> u64 {
    1
}
fn default_block_duration() -> u64 {
    3600
}
fn default_banner() -> String {
    "SSH-2.0-OpenSSH_7.9p1 Debian-10+deb9u2\r\n".into()
}

impl Default for DefenderConfig {
    fn default() -> Self {
        Self {
            ports: default_ports(),
            anomaly_threshold: default_threshold(),
            max_history_size: default_history(),
            enable_firewall: true,
            firewall_backend: default_firewall_backend(),
            blocklist_path: Some("blocklist.json".into()),
            per_ip_rate_limit: default_per_ip_limit(),
            per_ip_window_secs: default_rate_window(),
            block_duration_secs: default_block_duration(),
            whitelist: vec![
                "127.0.0.1/32".into(),
                "::1/128".into(),
            ],
            debug_mode: false,
            ssh_banner: default_banner(),
        }
    }
}

impl DefenderConfig {
    pub fn load(path: &Path) -> anyhow::Result<Self> {
        let content = fs::read_to_string(path)?;
        let cfg: Self = toml::from_str(&content)?;
        Ok(cfg)
    }

    pub fn parsed_whitelist(&self) -> Vec<IpNet> {
        self.whitelist
            .iter()
            .filter_map(|s| {
                s.parse::<IpNet>()
                    .or_else(|_| s.parse::<IpAddr>().map(|a| IpNet::from(a)))
                    .ok()
            })
            .collect()
    }

    pub fn is_whitelisted(&self, ip: IpAddr) -> bool {
        self.parsed_whitelist().iter().any(|net| net.contains(&ip))
    }

    pub fn log_summary(&self) {
        info!("📋 Configuration:");
        info!("   🔌 Ports: {:?}", self.ports);
        info!("   📊 Global anomaly threshold: {} conn/sec", self.anomaly_threshold);
        info!("   🚦 Per-IP rate limit: {} conn/{}s", self.per_ip_rate_limit, self.per_ip_window_secs);
        info!("   ⏱  Block duration: {}s", self.block_duration_secs);
        info!("   🔥 Firewall: {} (backend: {})",
            if self.enable_firewall { "enabled" } else { "disabled" },
            self.firewall_backend);
        info!("   🛡  Whitelist entries: {}", self.whitelist.len());
        info!("   📚 History size: {}", self.max_history_size);
    }
}
