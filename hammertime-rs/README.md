# 🛡️ HammerTime (Rust)

**Rust rewrite & enhancement** of [alexanderdfox/HammerTime](https://github.com/alexanderdfox/HammerTime) — a real-time TCP traffic defender originally written in Swift + C.

It monitors TCP connection rates, detects anomalies, mutates defensive logic, switches execution timelines, applies per-IP rate limits, maintains a whitelist, and can push blocks to the system firewall.

## Features

| Feature | Original (Swift) | This rewrite |
|---------|------------------|--------------|
| Multi-port TCP listeners | ✅ | ✅ |
| Connection rate tracking | ✅ | ✅ |
| TimeVariable + rewind | ✅ | ✅ |
| FunctionSwapper (logic mutation) | ✅ | ✅ |
| RealityFork (alpha / omega timelines) | ✅ | ✅ |
| CoreML anomaly model | ✅ (macOS) | Threshold + statistical (cross-platform) |
| SSH banner honeypot | ✅ | ✅ |
| Firewall blocking | pfctl (macOS) | iptables / nftables / pf (auto) |
| **Per-IP rate limiting** | ❌ | ✅ |
| **IP / CIDR whitelist** | ❌ | ✅ |
| **TOML configuration** | ❌ | ✅ |
| **Persistent blocklist** | ❌ | ✅ |
| **Temporary blocks with expiry** | ❌ | ✅ |
| **Structured metrics** | ❌ | ✅ |
| **Async (Tokio)** | ❌ | ✅ |
| **Cross-platform** | macOS | Linux + macOS/BSD |

## Quick start

```bash
# Build
cargo build --release

# Run with defaults (or config/hammertime.toml)
sudo ./target/release/hammertime

# Debug / dry-run (no real firewall rules)
./target/release/hammertime --debug --verbose

# Override ports / threshold
./target/release/hammertime --ports 2222,8080 --threshold 50
```

### Configuration

Edit `config/hammertime.toml` or pass `--config /path/to/file.toml`.

Key options:

- `ports` – list of TCP ports to listen on
- `anomaly_threshold` – global connections/sec that trigger the anomaly path
- `per_ip_rate_limit` / `per_ip_window_secs` – per-IP sliding-window limit
- `block_duration_secs` – how long a block lasts (0 = until restart)
- `whitelist` – IPs or CIDRs that are never blocked
- `firewall_backend` – `auto` | `iptables` | `nftables` | `pf` | `none`
- `blocklist_path` – JSON file used to persist blocks across restarts

## Architecture

```
src/
├── main.rs          # CLI, logging, lifecycle
├── config.rs        # TOML config + defaults
├── defender.rs      # Core logic, rate limiting, blocklist
├── listener.rs      # Async multi-port TCP accept + honeypot
├── temporal.rs      # TimeVariable, FunctionSwapper, RealityFork
├── firewall.rs      # iptables / nftables / pf abstraction
├── metrics.rs       # Atomic counters
└── ip.rs            # IP helpers
```

## Example output

```
🛡️  HammerTime (Rust) — Advanced DDoS Protection
📋 Configuration:
   🔌 Ports: [22, 80, 443, 2222]
   📊 Global anomaly threshold: 200 conn/sec
   🚦 Per-IP rate limit: 15 conn/1s
   …
✅ Port 22 is now LISTENING
…

⏱️  Connection Statistics (Last Second)
   🔢 Total: 23 connections
📊 Traffic Analysis Report
   📈 Current Rate: 23 connections/sec
   ✅ Traffic is within normal parameters
🌱 Alpha Fork: Normalized behavior profile.

🔗 New connection: 203.0.113.45 → port 22
   🎭 Sent SSH-2.0 banner to 203.0.113.45 (honeypot)

🚦 Per-IP rate limit exceeded for 198.51.100.10 (18 > 15 in 1s)
🚫 BLOCKING IP ADDRESS
   📍 IP: 198.51.100.10
   📝 Reason: per-IP rate limit exceeded
   ✅ Firewall rule applied
```

## Security notes

- Firewall commands are run via `sudo -n`. Configure passwordless sudo for the chosen backend, or run the binary as root.
- Always keep management / monitoring hosts in the whitelist.
- In `--debug` mode the firewall is completely disabled (safe for testing).

## Original project

This is a community rewrite of the excellent [HammerTime](https://github.com/alexanderdfox/HammerTime) by Alexander D. Fox.  
All credit for the original design (TimeVariable, FunctionSwapper, RealityFork, CoreML integration) belongs to the upstream author.

## License

MIT (same as the original).
