//! Simple in-memory metrics counters.

use std::sync::atomic::{AtomicU64, Ordering};
use tracing::info;

pub struct Metrics {
    pub total_connections: AtomicU64,
    pub blocked_connections: AtomicU64,
    pub blocked_ips: AtomicU64,
    pub anomalies_detected: AtomicU64,
    pub rate_limit_triggers: AtomicU64,
}

impl Metrics {
    pub fn new() -> Self {
        Self {
            total_connections: AtomicU64::new(0),
            blocked_connections: AtomicU64::new(0),
            blocked_ips: AtomicU64::new(0),
            anomalies_detected: AtomicU64::new(0),
            rate_limit_triggers: AtomicU64::new(0),
        }
    }

    pub fn inc_connections(&self) {
        self.total_connections.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_blocked_conn(&self) {
        self.blocked_connections.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_blocked_ip(&self) {
        self.blocked_ips.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_anomaly(&self) {
        self.anomalies_detected.fetch_add(1, Ordering::Relaxed);
    }

    pub fn inc_rate_limit(&self) {
        self.rate_limit_triggers.fetch_add(1, Ordering::Relaxed);
    }

    pub fn print_summary(&self) {
        info!("");
        info!("📊 ═══ Session Metrics ═══");
        info!("   Total connections seen : {}", self.total_connections.load(Ordering::Relaxed));
        info!("   Blocked connections    : {}", self.blocked_connections.load(Ordering::Relaxed));
        info!("   Unique IPs blocked     : {}", self.blocked_ips.load(Ordering::Relaxed));
        info!("   Anomalies detected     : {}", self.anomalies_detected.load(Ordering::Relaxed));
        info!("   Per-IP rate-limit hits : {}", self.rate_limit_triggers.load(Ordering::Relaxed));
        info!("══════════════════════════");
    }
}

impl Default for Metrics {
    fn default() -> Self {
        Self::new()
    }
}
