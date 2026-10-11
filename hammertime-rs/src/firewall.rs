//! Cross-platform firewall abstraction.
//! Supports iptables, nftables (Linux) and pfctl (macOS/BSD).
//! In debug mode or when backend = "none", actions are logged only.

use crate::ip::TrackedIp;
use std::process::Command;
use tracing::{error, info, warn};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FirewallBackend {
    None,
    Iptables,
    Nftables,
    Pf,
}

impl FirewallBackend {
    pub fn detect(preferred: &str) -> Self {
        match preferred.to_lowercase().as_str() {
            "none" => return FirewallBackend::None,
            "iptables" => return FirewallBackend::Iptables,
            "nftables" => return FirewallBackend::Nftables,
            "pf" | "pfctl" => return FirewallBackend::Pf,
            _ => {} // auto
        }

        // Auto-detect
        if cfg!(target_os = "linux") {
            if Command::new("nft").arg("--version").output().is_ok() {
                return FirewallBackend::Nftables;
            }
            if Command::new("iptables").arg("--version").output().is_ok() {
                return FirewallBackend::Iptables;
            }
        }
        if cfg!(any(target_os = "macos", target_os = "freebsd", target_os = "openbsd")) {
            if Command::new("pfctl").arg("-s").arg("info").output().is_ok() {
                return FirewallBackend::Pf;
            }
        }
        warn!("No supported firewall backend detected — using dry-run (None)");
        FirewallBackend::None
    }
}

pub struct Firewall {
    backend: FirewallBackend,
    enabled: bool,
    anchor: String,
}

impl Firewall {
    pub fn new(backend_str: &str, enabled: bool) -> Self {
        let backend = if enabled {
            FirewallBackend::detect(backend_str)
        } else {
            FirewallBackend::None
        };
        info!("🔥 Firewall backend: {:?}", backend);
        Self {
            backend,
            enabled,
            anchor: "hammertime".into(),
        }
    }

    pub fn block(&self, ip: &TrackedIp) -> bool {
        if !self.enabled || self.backend == FirewallBackend::None {
            info!("   ⚠️  Firewall disabled / dry-run — would block {}", ip);
            return true;
        }

        let result = match self.backend {
            FirewallBackend::Iptables => self.block_iptables(ip),
            FirewallBackend::Nftables => self.block_nftables(ip),
            FirewallBackend::Pf => self.block_pf(ip),
            FirewallBackend::None => Ok(()),
        };

        match result {
            Ok(()) => {
                info!("   ✅ Firewall rule applied for {}", ip.firewall_format());
                true
            }
            Err(e) => {
                error!("   ❌ Firewall command failed: {}", e);
                false
            }
        }
    }

    fn block_iptables(&self, ip: &TrackedIp) -> anyhow::Result<()> {
        // Prefer a dedicated chain if it exists; otherwise append to INPUT
        let output = Command::new("sudo")
            .args([
                "-n",
                "iptables",
                "-I",
                "INPUT",
                "-s",
                &ip.addr.to_string(),
                "-j",
                "DROP",
            ])
            .output()?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("iptables failed: {}", stderr);
        }
        Ok(())
    }

    fn block_nftables(&self, ip: &TrackedIp) -> anyhow::Result<()> {
        // Simple rule; production should use a dedicated set + chain
        let rule = format!(
            "add rule inet filter input ip saddr {} drop",
            ip.addr
        );
        let output = Command::new("sudo")
            .args(["-n", "nft", &rule])
            .output()?;

        if !output.status.success() {
            // Fallback: try creating a simple set if it doesn't exist
            let _ = Command::new("sudo")
                .args(["-n", "nft", "add table inet filter"])
                .output();
            let _ = Command::new("sudo")
                .args([
                    "-n",
                    "nft",
                    "add chain inet filter input { type filter hook input priority 0; }",
                ])
                .output();
            let output2 = Command::new("sudo")
                .args(["-n", "nft", &rule])
                .output()?;
            if !output2.status.success() {
                let stderr = String::from_utf8_lossy(&output2.stderr);
                anyhow::bail!("nftables failed: {}", stderr);
            }
        }
        Ok(())
    }

    fn block_pf(&self, ip: &TrackedIp) -> anyhow::Result<()> {
        // Use pfctl anchor similar to original Swift code
        let rule = format!("block drop from {} to any\n", ip.firewall_format());
        let mut child = Command::new("sudo")
            .args(["-n", "pfctl", "-a", &self.anchor, "-f", "-"])
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::piped())
            .spawn()?;

        if let Some(mut stdin) = child.stdin.take() {
            use std::io::Write;
            stdin.write_all(rule.as_bytes())?;
        }

        let output = child.wait_with_output()?;
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("pfctl failed: {}", stderr);
        }
        Ok(())
    }
}
