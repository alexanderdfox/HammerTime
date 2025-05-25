
# Hammer4D Defender v3

## Overview

Hammer4D Defender is an experimental network defense prototype written in Swift. It monitors real-time TCP connection rates on port 8080 and dynamically adapts its detection logic using advanced concepts like temporal tracking, logic mutation, and multiverse execution (reality forks).

It aims to demonstrate adaptive cybersecurity defenses that respond to suspicious traffic spikes by mutating defense logic and switching between defense timelines.

---

## Features

- Real-time monitoring of incoming TCP connections.
- Tracks requests per second with temporal history and rewind capability.
- Dynamic mutation of detection logic based on traffic conditions.
- Multiple timeline strategies for adaptive defense.
- Console output for live monitoring and state transitions.

---

## Requirements

- macOS or Linux system.
- Swift 5.6 or newer installed.
- Permission to bind TCP port 8080.

---

## Installation & Running

1. Clone or download the project source code.

2. Open terminal and navigate to the project directory.

3. Build the project:

   ```bash
   swift build
   ```

4. Run the executable:

   ```bash
   swift run
   ```

5. The program will start listening on TCP port 8080 and print logs to the console.

6. To test, generate TCP connections to port 8080, for example:

   ```bash
   nc localhost 8080
   ```

   Opening many connections quickly will trigger high traffic detection and logic mutation.

---

## Configuration

- The high traffic detection threshold is currently set to 200 requests per second.
- Change this value in `Hammer4DDefenderCore.analyzeTraffic(rate:)` if needed.
- The listening port (default 8080) can be changed in the `TCPListener` class.

---

## Limitations

- Prototype only, not production-ready.
- No real packet filtering or blocking implemented.
- Only counts connection attempts, not traffic content.
- Running on privileged ports may require elevated permissions.

---

## Contributing

Feel free to fork, enhance, or report issues via GitHub.

---

## License

Provided as-is for educational and prototyping purposes.

---

Enjoy exploring adaptive network defense powered by temporal logic! 🚀
