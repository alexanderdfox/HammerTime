# Debug Mode Guide

This document explains the debugging features available in HammerTime.

## Debug Modes

### 1. Debug Mode (`--debug` or `-d`)

Enables comprehensive debugging output and disables firewall for safety.

**Features:**
- 🐛 Detailed debug logging
- 🔍 Verbose connection tracking
- 📊 Enhanced statistics
- 🔥 Firewall disabled (for safety during testing)
- 🧠 ML model prediction details

**Usage:**
```bash
# Command line flag
./build/bin/Hammer4DDefender --debug

# Or with environment variable
DEBUG=1 ./build/bin/Hammer4DDefender

# Or using make
make run DEBUG=1
```

### 2. Verbose Mode (`--verbose` or `-v`)

Enables verbose logging without disabling firewall.

**Features:**
- 🔍 Detailed connection information
- 📝 Extended logging output
- 🔍 ML model status details
- ✅ Firewall remains enabled

**Usage:**
```bash
# Command line flag
./build/bin/Hammer4DDefender --verbose

# Or with environment variable
VERBOSE=1 ./build/bin/Hammer4DDefender
```

### 3. Combined Mode

You can use both debug and verbose modes together:

```bash
./build/bin/Hammer4DDefender --debug --verbose
```

## Debug Output

### Connection Debugging

When debug mode is enabled, you'll see:

```
🐛 DEBUG: New connection received on port 22
🔍 VERBOSE: Connection endpoint: hostPort(ipv4(192.168.1.100), port 22)
🐛 DEBUG: Extracted IP: 192.168.1.100 (IPv4)
🐛 DEBUG: Connection accepted, adding to count for port 22
```

### ML Model Debugging

Debug output for ML predictions:

```
🐛 DEBUG: Running ML prediction for rate: 150
🐛 DEBUG: ML input created: [150]
🐛 DEBUG: ML prediction result: NORMAL (value: 0)
```

### Traffic Analysis Debugging

```
🐛 DEBUG: Analyzing traffic: rate=150, history_size=45
🐛 DEBUG: ML result: false, threshold exceeded: false, isAnomalous: false
```

### Timer Debugging

```
🐛 DEBUG: Timer tick: total=5, details=[22: 3, 80: 2]
```

## Debug Features

### 1. Enhanced Logging

- **Debug Logs**: `Logger.debug()` - Only shown in debug/verbose mode
- **Verbose Logs**: `Logger.verbose()` - Only shown in verbose mode
- **Regular Logs**: Always shown

### 2. Connection Tracking

- Detailed connection endpoint information
- IP extraction debugging
- Blocklist check debugging
- Connection state transitions

### 3. ML Model Diagnostics

- Model loading status
- Prediction input/output
- Error details
- Model availability status

### 4. Traffic Analysis

- Rate calculation details
- History size tracking
- Threshold comparisons
- ML vs threshold detection

### 5. Firewall Debugging

- Rule application status
- Command execution details
- Error output capture
- IP sanitization steps

## Configuration

Debug mode can be configured in code:

```swift
// Debug configuration (firewall disabled)
let config = DefenderConfig.debug(ports: [22, 80, 443])

// Custom debug config
let config = DefenderConfig(
    ports: [22, 80, 443, 2222],
    anomalyThreshold: 200,
    mlModelPath: nil,
    maxHistorySize: 1000,
    enableFirewall: false,  // Disabled for safety
    firewallAnchor: "com.hammer4d",
    debugMode: true,
    verboseLogging: true
)
```

## Debug Build

Use the Makefile debug target for debug symbols:

```bash
make debug
```

This builds with:
- `-g` flag for debug symbols
- `-Onone` for no optimization
- Full debugging information

## Troubleshooting

### Enable Debug Mode

If you're experiencing issues:

1. **Run with debug mode:**
   ```bash
   ./build/bin/Hammer4DDefender --debug
   ```

2. **Check debug output:**
   - Look for `🐛 DEBUG:` messages
   - Check connection details
   - Verify ML model status

3. **Common issues:**
   - ML model not loading → Check model path
   - Connections not detected → Check port bindings
   - Firewall rules failing → Check sudo permissions

### Debug Log Categories

Logs are categorized:
- `general` - General application logs
- `traffic` - Traffic analysis logs
- `security` - Security/blocking logs
- `ml` - Machine learning logs
- `debug` - Debug-specific logs

### Viewing Logs

On macOS, you can view logs using:

```bash
# View system logs
log stream --predicate 'subsystem == "com.hammer4d.defender"'

# View specific category
log stream --predicate 'subsystem == "com.hammer4d.defender" AND category == "debug"'
```

## Examples

### Example 1: Debugging Connection Issues

```bash
# Run with debug mode
./build/bin/Hammer4DDefender --debug

# Output will show:
# 🐛 DEBUG: New connection received on port 22
# 🐛 DEBUG: Extracted IP: 192.168.1.100 (IPv4)
# 🔗 New connection: 192.168.1.100 → port 22
```

### Example 2: Debugging ML Model

```bash
# Run with verbose mode
./build/bin/Hammer4DDefender --verbose

# Output will show:
# 🐛 DEBUG: Running ML prediction for rate: 250
# 🐛 DEBUG: ML input created: [250]
# 🐛 DEBUG: ML prediction result: ANOMALY (value: 1)
```

### Example 3: Debugging Traffic Analysis

```bash
# Run with debug mode
./build/bin/Hammer4DDefender --debug

# Output will show:
# 🐛 DEBUG: Analyzing traffic: rate=250, history_size=100
# 🐛 DEBUG: ML result: true, threshold exceeded: true, isAnomalous: true
# 🚨🚨🚨 ALERT: ANOMALOUS TRAFFIC DETECTED 🚨🚨🚨
```

## Safety Features

When debug mode is enabled:
- ✅ Firewall is automatically disabled
- ✅ More detailed error messages
- ✅ Enhanced logging for troubleshooting
- ✅ No actual blocking occurs (testing safe)

## Best Practices

1. **Use debug mode for development:**
   - Test new features
   - Troubleshoot issues
   - Verify behavior

2. **Use verbose mode for production debugging:**
   - Keep firewall enabled
   - Get detailed logs
   - Monitor system behavior

3. **Disable in production:**
   - Debug mode adds overhead
   - Verbose logging can be verbose
   - Use only when needed

## Environment Variables

You can also set debug mode via environment variables:

```bash
# Debug mode
export DEBUG=1
./build/bin/Hammer4DDefender

# Verbose mode
export VERBOSE=1
./build/bin/Hammer4DDefender

# Both
export DEBUG=1 VERBOSE=1
./build/bin/Hammer4DDefender
```

