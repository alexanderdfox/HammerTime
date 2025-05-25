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

## 📦 Installation

1. **Clone the repo**

```bash
git clone https://github.com/alexanderdfox/HammerTime.git
cd HammerTime
```

2. **Open in Xcode**

Ensure you are using **Xcode 14+** and **Swift 5.7+**.

3. **Add CoreML Model**

Download or generate a CoreML `.mlmodel` and add it to your project:
- [🔗 Download Example: `AnomalyDetector.mlmodel`](https://github.com/alexanderdfox/HammerTime/releases)

Make sure your model has:
- **Input:** `request_rate` (`Double`)
- **Output:** `isAnomalous` (`Int` or `Bool`)

---

## 🧠 Train Your Own Anomaly Model (Optional)

You can generate your own `.mlmodel` using the provided Python script in [`/ml_model`](ml_model/). It uses `IsolationForest` from scikit-learn.

```bash
cd ml_model
python train_anomaly_model.py
```

---

## 🛠 Usage

Simply run the main Swift file:

```bash
swift run
```

Or hit the ▶️ **Run** button in Xcode. It starts a TCP listener on port **8080**, tracking traffic per second.

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
