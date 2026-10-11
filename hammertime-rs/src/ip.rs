//! IP address helpers and validation.

use std::net::IpAddr;
use std::str::FromStr;

/// Convenience wrapper that preserves the original string form when useful.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct TrackedIp {
    pub addr: IpAddr,
}

impl TrackedIp {
    pub fn new(addr: IpAddr) -> Self {
        Self { addr }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        IpAddr::from_str(s.trim()).ok().map(Self::new)
    }

    pub fn is_v4(&self) -> bool {
        self.addr.is_ipv4()
    }

    pub fn is_v6(&self) -> bool {
        self.addr.is_ipv6()
    }

    /// Format suitable for firewall rules.
    pub fn firewall_format(&self) -> String {
        match self.addr {
            IpAddr::V4(v4) => v4.to_string(),
            IpAddr::V6(v6) => format!("[{}]", v6),
        }
    }
}

impl std::fmt::Display for TrackedIp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.addr)
    }
}

impl From<IpAddr> for TrackedIp {
    fn from(addr: IpAddr) -> Self {
        Self::new(addr)
    }
}
