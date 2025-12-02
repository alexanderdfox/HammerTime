# 🧪 HammerTime Usage Guide

## 🖥️ Running the Defender

Run the `main()` function in `Hammer4DDefender.swift` using Xcode or Swift CLI:

```bash
swift Hammer4DDefender.swift
```

The system will:

- Start listening on TCP port `8080`
- Track the number of incoming TCP connections per second
- Analyze connection rate with a CoreML model
- Mutate behavior logic if an anomaly is detected
- Switch between execution timelines (e.g. `alpha`, `omega`)

---

## 🛡 Threat Simulation

You can simulate TCP requests using tools like `telnet`, `curl`, or Python scripts:

```bash
# Simulate normal traffic
for i in {1..50}; do nc localhost 8080 & done

# Simulate high traffic
for i in {1..500}; do nc localhost 8080 & done
```

---

## 🧠 CoreML Model Integration

To use anomaly detection:

1. Add your `.mlmodel` to the Xcode project
2. Ensure it has:
   - Input: `request_rate` (Double)
   - Output: `isAnomalous` (Int or Bool)

You can use the included training script in `ml_model/train_anomaly_model.py` to create your own.

---

## 🔄 Extending Timelines

To define new behavior branches:

```swift
realityFork.register(.beta) {
    print("⚙️ Beta Fork: Experimental defense.")
}
```

Then switch with:

```swift
realityFork.switchTo(.beta)
```

---

## 📊 Viewing History

Each `TimeVariable<T>` tracks historical values. To dump traffic history:

```swift
print(requestRate.historyDump())
```

This is useful for timeline forensics and replay debugging.

---

## 📬 Feedback

Please [open an issue](https://github.com/alexanderdfox/HammerTime/issues) or submit a PR with suggestions or improvements.
