# 🛡 HammerTime: Hammer4D Defender

**HammerTime** is a Swift-based, real-time anti-DDoS and threat detection system. It monitors TCP traffic, tracks connection rates temporally, detects anomalies via a CoreML model, and mutates defensive logic in response to detected threats — simulating a multi-timeline defense strategy.

---

## 🚀 Features

- 🔍 **Real-time TCP connection rate monitoring**
- ⏳ **TimeVariable tracking** with rewind capabilities
- 🧬 **FunctionSwapper** for logic mutation under attack
- 🌐 **RealityFork** timeline-based execution (e.g. alpha, omega)
- 🧠 **CoreML integration** to detect anomalous network behavior
- 🔁 Auto-adapts to normal or polymorphic traffic patterns

---

## 📁 Project Structure

```
HammerTime/
├── src/              # Source code (Swift, C)
│   ├── hammer.swift
│   └── PacketSniffer.c
├── include/          # Header files
│   ├── PacketSniffer.h
│   └── Bridging-Header.h
├── docs/             # Documentation
│   ├── DEBUG.md
│   ├── IMPROVEMENTS.md
│   └── ...
├── ml_model/         # ML model training
│   ├── train_anomaly_model.py
│   └── AnomalyDetector.mlmodel
├── build/            # Build output (generated)
├── CompiledModel/    # Compiled ML models (generated)
├── Makefile          # Build configuration
└── README.md         # This file
```

## 📦 Installation

1. **Clone the repo**

```bash
git clone https://github.com/alexanderdfox/HammerTime.git
cd HammerTime
```

2. **Build the project**

```bash
make
```

Or use the Makefile directly:

```bash
# Build the project
make

# Build and run
make run

# Build with debug symbols
make debug
```

3. **Add CoreML Model**

Generate a CoreML `.mlmodel` and add it to your project:

Make sure your model has:
- **Input:** `request_rate` (`Double`)
- **Output:** `isAnomalous` (`Int` or `Bool`)

---

## 🧠 Train Your Own Anomaly Model 

You can generate your own `.mlmodel` using the provided Python script in [`/ml_model`](ml_model/). It uses `IsolationForest` from scikit-learn.

```bash
cd ml_model
python train_anomaly_model.py
```

---

## 🛠 Usage

### Using Makefile (Recommended)

```bash
# Build the project
make

# Build and run
make run

# Build with debug symbols
make debug

# Build optimized release
make release

# Train ML model
make train-model

# See all options
make help
```

### Direct Execution

```bash
# After building
./build/bin/Hammer4DDefender

# With debug mode
./build/bin/Hammer4DDefender --debug

# With verbose logging
./build/bin/Hammer4DDefender --verbose
```

The application starts TCP listeners on ports **22, 80, 443, 2222** by default, tracking traffic per second.

---

## 🧪 Example Output

```
📡 Listening on TCP port 8080...
⏱️ Second:
📈 Request Rate: 23/sec
🧪 Executing timeline: alpha
🔍 Traffic normal.

⏱️ Second:
📈 Request Rate: 401/sec
🚨 High traffic detected!
🔁 Rewound value to: 23
🛠️ Logic mutated!
🌐 Timeline switched to: omega
🔥 Omega Fork: Polymorphic logic running...
```

---

## 📄 License

MIT License. See `LICENSE.md`.

---

## 👤 Author

**Alexander D. Fox**  
🔗 [github.com/alexanderdfox](https://github.com/alexanderdfox)
