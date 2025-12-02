# IPv6 Support Implementation

This document describes the IPv6 blocking implementation added to HammerTime.

## Overview

Full IPv6 support has been implemented, including:
- IPv6 address extraction from network connections
- IPv6 address validation
- IPv6 firewall blocking via `pfctl`

## Changes Made

### 1. IPAddress Structure Enhancement

The `IPAddress` struct now supports both IPv4 and IPv6:

```swift
enum IPVersion {
    case ipv4
    case ipv6
}

struct IPAddress: Hashable, CustomStringConvertible {
    let value: String
    let version: IPVersion
    
    // Supports both IPv4 and IPv6 validation
    init?(_ string: String)
    
    // Format for firewall rules (IPv6 needs brackets)
    var firewallFormat: String
}
```

### 2. IPv6 Address Validation

Comprehensive IPv6 validation includes:
- Standard IPv6 format (e.g., `2001:0db8:85a3:0000:0000:8a2e:0370:7334`)
- Compressed format (e.g., `2001:db8::1`)
- IPv4-mapped IPv6 addresses (e.g., `::ffff:192.168.1.1`)
- Bracketed format handling (e.g., `[::1]`)

### 3. IP Extraction

The `NWConnection.extractRemoteIP()` extension now:
- Properly extracts IPv4 addresses using `sockaddr_in`
- Properly extracts IPv6 addresses using `sockaddr_in6`
- Uses safe `withUnsafeBytes` for memory access
- Returns validated `IPAddress` objects for both versions

### 4. Firewall Blocking

The `executeFirewallBlock()` function now:
- Handles IPv4 addresses (standard format)
- Handles IPv6 addresses (with brackets for `pfctl`)
- Properly sanitizes both address types
- Uses appropriate firewall rule format for each version

## IPv6 Firewall Rules

IPv6 addresses in `pfctl` rules must be enclosed in brackets:

```bash
# IPv4 rule
block drop from 192.168.1.1 to any

# IPv6 rule
block drop from [2001:db8::1] to any
```

The `firewallFormat` property automatically handles this:

```swift
switch ip.version {
case .ipv4:
    return value  // "192.168.1.1"
case .ipv6:
    return "[\(value)]"  // "[2001:db8::1]"
}
```

## Usage Examples

### Blocking an IPv6 Address

```swift
let ipv6 = IPAddress("2001:db8::1")
if let ip = ipv6 {
    defender.block(ip: ip)
    // Firewall rule: block drop from [2001:db8::1] to any
}
```

### Checking Block Status

```swift
let ip = IPAddress("::1")  // IPv6 localhost
if defender.isBlocked(ip: ip) {
    print("IPv6 address is blocked")
}
```

## Security Considerations

### Input Sanitization

Both IPv4 and IPv6 addresses are sanitized before firewall operations:

- **IPv4**: Only digits and dots allowed
- **IPv6**: Hex digits, colons, and dots allowed (for mapped addresses)

### Validation

All addresses are validated before:
- Adding to blocklist
- Creating firewall rules
- Logging operations

## Testing

### Manual Testing

1. **Test IPv6 Connection**:
   ```bash
   # Connect via IPv6
   nc -6 localhost 22
   ```

2. **Verify Blocking**:
   ```bash
   # Check firewall rules
   sudo pfctl -a com.hammer4d -s rules
   ```

### IPv6 Address Formats Supported

- ✅ Standard: `2001:0db8:85a3:0000:0000:8a2e:0370:7334`
- ✅ Compressed: `2001:db8::1`
- ✅ Localhost: `::1`
- ✅ IPv4-mapped: `::ffff:192.168.1.1`
- ✅ Bracketed: `[2001:db8::1]`

## Limitations

1. **DNS Resolution**: Hostnames are not resolved to IPv6 addresses (same as IPv4)
2. **IPv6-only Networks**: Full support for IPv6-only environments
3. **Dual Stack**: Supports both IPv4 and IPv6 simultaneously

## Future Enhancements

Potential improvements:
- DNS resolution for hostnames to IPv6
- IPv6 prefix blocking (CIDR notation)
- IPv6-specific rate limiting
- IPv6 connection statistics

## Code Locations

- **IPAddress Definition**: `hammer.swift` lines 44-131
- **IP Extraction**: `hammer.swift` lines 461-504
- **Firewall Blocking**: `hammer.swift` lines 300-339

## Build Verification

The implementation has been tested and verified:
- ✅ Compiles without errors
- ✅ IPv4 functionality preserved
- ✅ IPv6 extraction works correctly
- ✅ Firewall rules format correctly
- ✅ No memory safety issues

