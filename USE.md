
# Hammer4D Defender v3 — Usage Guide

## Overview

Hammer4D Defender is a prototype network traffic defense tool written in Swift. It listens on TCP port 8080 and monitors incoming TCP connection rates in real time. The system uses advanced concepts such as:

- **Temporal Variable Tracking** — keeps history of network metrics with rewind capability.
- **Logic Mutation** — dynamically swaps detection logic functions based on traffic.
- **Multiverse Execution / Reality Forks** — switches between alternative defense strategies (timelines) adaptively.

This allows the defender to detect sudden spikes in traffic (potential attacks) and mutate its detection logic accordingly, enhancing adaptive cybersecurity defenses.

---

## Features

- **Real-time TCP connection monitoring** on port 8080.
- Tracks **requests per second** with history tracking and rewind.
- Automatically detects **high traffic spikes** above a configurable threshold (default 200 connections/second).
- Dynamically **mutates defense logic** and switches between different "timeline" strategies:
  - `.alpha` — Normal traffic behavior.
  - `.omega` — Polymorphic, attack-focused defense mode.
- Console output for monitoring state transitions and detected events.

---

## Requirements

- macOS or Linux system with Swift 5.6+ installed.
- Network permissions to listen on TCP port 8080.

---

## How to Run

1. **Build the project:**

   ```bash
   swift build
   ```

2. **Run the executable:**

   ```bash
   swift run
   ```

3. The program will start listening on TCP port 8080 and print status updates to the console.

4. **Generate traffic** (for testing) by opening multiple TCP connections to port 8080. For example, in another terminal:

   ```bash
   nc localhost 8080
   ```

   Open many such connections quickly to trigger high traffic detection.

---

## Console Output

- `📡 Listening on TCP port 8080...` — indicates the server is ready.
- `📈 Request Rate: X/sec` — number of connections received in the last second.
- `🚨 High traffic detected!` — detected suspiciously high request rate.
- `🔄 Rewound value to: Y` — temporal tracker rewound to previous state.
- `🛠️ Logic mutated!` — detection logic changed dynamically.
- `🌐 Timeline switched to: omega` — switched to attack-defense timeline.
- `🔥 Omega Fork: Polymorphic logic running...` — active defense behavior during attacks.
- `🌱 Alpha Fork: Normalized behavior profile.` — normal traffic behavior.

---

## Configuration

- The high traffic threshold is currently hardcoded as **200 requests per second** in `Hammer4DDefenderCore.analyzeTraffic(rate:)`.
- You can adjust this value by modifying the `if rate > 200` condition in the source code.
- TCP port is set to `8080` but can be changed in the `TCPListener` class.

---

## Extending and Customizing

- Add more timelines in `RealityFork` to simulate other defense or analysis strategies.
- Enhance the `FunctionSwapper` to perform real mitigation or alerting logic instead of print statements.
- Implement packet inspection or throttling in the `handleConnection` method.
- Add persistent logging or integrate with external monitoring dashboards.
- Integrate machine learning models for smarter anomaly detection.

---

## Limitations

- This is a prototype focused on demonstrating concepts; it is **not production-ready**.
- No real packet filtering, rate limiting, or threat blocking implemented yet.
- Only counts connection attempts, not traffic payload or other network metrics.
- Listening on port 8080 may require admin privileges depending on system configuration.

---

## License

This project is provided as-is for educational and prototyping purposes.

---

## Contact

For questions, feedback, or contributions, please open an issue or pull request.

---

Enjoy experimenting with adaptive network defense powered by temporal logic and multiverse execution! 🚀
