import Foundation
import Network
import CoreML
import os.log
import Darwin
import Darwin.C

// MARK: - Logging

enum Logger {
	private static let subsystem = "com.hammer4d.defender"
	static let general = OSLog(subsystem: subsystem, category: "general")
	static let traffic = OSLog(subsystem: subsystem, category: "traffic")
	static let security = OSLog(subsystem: subsystem, category: "security")
	static let ml = OSLog(subsystem: subsystem, category: "ml")
	static let debug = OSLog(subsystem: subsystem, category: "debug")
	
	private static var isDebugMode = false
	private static var isVerboseMode = false
	private static var clearScreenEnabled = true
	
	// ANSI escape codes
	private static let clearScreen = "\u{1B}[2J"
	private static let moveToHome = "\u{1B}[H"
	
	static func setDebugMode(_ enabled: Bool) {
		isDebugMode = enabled
	}
	
	static func setVerboseMode(_ enabled: Bool) {
		isVerboseMode = enabled
	}
	
	static func setClearScreen(_ enabled: Bool) {
		clearScreenEnabled = enabled
	}
	
	private static func clearAndPrint(_ message: String) {
		if clearScreenEnabled {
			// Clear screen and move cursor to home position
			print(clearScreen + moveToHome, terminator: "")
			fflush(stdout)
		}
		print(message)
		fflush(stdout)
	}
	
	static func log(_ message: String, type: OSLogType = .default, log: OSLog = general) {
		// Print to console (stdout/stderr) with immediate flush
		if type == .error || type == .fault {
			// Don't clear screen for errors, just print
			let data = (message + "\n").data(using: .utf8) ?? Data()
			FileHandle.standardError.write(data)
			fflush(stderr) // Use fflush instead of synchronizeFile
		} else {
			clearAndPrint(message)
		}
		// Also log to system log
		os_log("%{public}@", log: log, type: type, message)
	}
	
	static func debug(_ message: String, log: OSLog = debug) {
		if isDebugMode || isVerboseMode {
			let debugMessage = "🐛 DEBUG: \(message)"
			// Print to console with immediate flush
			clearAndPrint(debugMessage)
			// Also log to system log
			os_log("🐛 DEBUG: %{public}@", log: log, type: .debug, message)
		}
	}
	
	static func verbose(_ message: String, log: OSLog = general) {
		if isVerboseMode {
			let verboseMessage = "🔍 VERBOSE: \(message)"
			// Print to console with immediate flush
			clearAndPrint(verboseMessage)
			// Also log to system log
			os_log("🔍 VERBOSE: %{public}@", log: log, type: .debug, message)
		}
	}
}

// MARK: - Configuration

struct DefenderConfig {
	let ports: [UInt16]
	let anomalyThreshold: Int
	let mlModelPath: String?
	let maxHistorySize: Int
	let enableFirewall: Bool
	let firewallAnchor: String
	let debugMode: Bool
	let verboseLogging: Bool
	
	static let `default` = DefenderConfig(
		ports: [22, 80, 443, 2222],
		anomalyThreshold: 200,
		mlModelPath: nil, // Will use default path
		maxHistorySize: 1000,
		enableFirewall: true,
		firewallAnchor: "com.hammer4d",
		debugMode: false,
		verboseLogging: false
	)
	
	// Create debug configuration
	static func debug(ports: [UInt16] = [22, 80, 443, 2222]) -> DefenderConfig {
		return DefenderConfig(
			ports: ports,
			anomalyThreshold: 200,
			mlModelPath: nil,
			maxHistorySize: 1000,
			enableFirewall: false, // Disable firewall in debug mode for safety
			firewallAnchor: "com.hammer4d",
			debugMode: true,
			verboseLogging: true
		)
	}
}

// MARK: - IP Address Type

enum IPVersion {
	case ipv4
	case ipv6
}

struct IPAddress: Hashable, CustomStringConvertible {
	let value: String
	let version: IPVersion
	
	init?(_ string: String) {
		// Try IPv4 first
		if Self.isValidIPv4(string) {
			self.value = string
			self.version = .ipv4
			return
		}
		
		// Try IPv6
		if Self.isValidIPv6(string) {
			self.value = string
			self.version = .ipv6
			return
		}
		
		return nil
	}
	
	private static func isValidIPv4(_ string: String) -> Bool {
		let parts = string.split(separator: ".")
		guard parts.count == 4 else { return false }
		
		return parts.allSatisfy { part in
			guard let num = Int(part), (0...255).contains(num) else { return false }
			return true
		}
	}
	
	private static func isValidIPv6(_ string: String) -> Bool {
		// Remove brackets if present (e.g., [::1])
		var addr = string.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
		
		// Handle IPv4-mapped IPv6 addresses (::ffff:192.168.1.1)
		if addr.contains(".") {
			// Split on last ::
			if let lastColon = addr.lastIndex(of: ":") {
				let ipv4Part = String(addr[addr.index(after: lastColon)...])
				if !isValidIPv4(ipv4Part) {
					return false
				}
				addr = String(addr[..<lastColon])
			} else {
				return false
			}
		}
		
		// Handle compressed format (::)
		let parts = addr.split(separator: ":", omittingEmptySubsequences: false)
		
		// IPv6 must have at most 8 parts (or 7 with :: compression)
		guard parts.count <= 8 else { return false }
		
		// Check for :: compression (only one allowed)
		let emptyCount = parts.filter { $0.isEmpty }.count
		guard emptyCount <= 1 else { return false }
		
		// Validate each hex part
		for part in parts {
			if part.isEmpty {
				continue // This is the :: compression
			}
			
			// Each part should be 1-4 hex digits
			guard (1...4).contains(part.count) else { return false }
			guard part.allSatisfy({ $0.isHexDigit }) else { return false }
		}
		
		return true
	}
	
	var description: String { value }
	
	// Format for firewall rules (IPv6 needs brackets)
	var firewallFormat: String {
		switch version {
		case .ipv4:
			return value
		case .ipv6:
			return "[\(value)]"
		}
	}
}

extension Character {
	var isHexDigit: Bool {
		let lowercased = self.lowercased()
		return ("0"..."9").contains(self) || ("a"..."f").contains(lowercased)
	}
}

// MARK: - Temporal Variable Tracker

class TimeVariable<T> {
	private var history: [T] = []
	private let maxHistorySize: Int
	private let historyQueue = DispatchQueue(label: "com.hammer4d.history", attributes: .concurrent)
	
	var value: T {
		didSet {
			historyQueue.async(flags: .barrier) { [weak self] in
				guard let self = self else { return }
				self.history.append(self.value)
				if self.history.count > self.maxHistorySize {
					self.history.removeFirst()
				}
			}
		}
	}

	init(initial: T, maxHistorySize: Int = 1000) {
		self.value = initial
		self.maxHistorySize = maxHistorySize
		history.append(initial)
	}

	func rewind(by steps: Int = 1) {
		historyQueue.sync {
			let index = max(0, history.count - steps - 1)
			value = history[index]
			Logger.log("🔄 Rewound value to: \(value)", log: Logger.general)
		}
	}

	func historyDump() -> [T] {
		return historyQueue.sync {
			return Array(history)
		}
	}
}

// MARK: - Logic Mutation (Function Swapping)

class FunctionSwapper {
	private var logic: () -> Void
	private let queue = DispatchQueue(label: "com.hammer4d.logic", attributes: .concurrent)

	init(initialLogic: @escaping () -> Void) {
		self.logic = initialLogic
	}

	func run() {
		queue.sync {
			logic()
		}
	}

	func mutate(newLogic: @escaping () -> Void) {
		queue.async(flags: .barrier) { [weak self] in
			guard let self = self else { return }
			self.logic = newLogic
			Logger.log("🛠️ Logic mutated!", log: Logger.general)
		}
	}
}

// MARK: - Multiverse Execution (Reality Forks)

enum Timeline: String {
	case alpha, beta, omega
}

class RealityFork {
	var current: Timeline = .alpha
	private var branches: [Timeline: () -> Void] = [:]

	func register(_ timeline: Timeline, logic: @escaping () -> Void) {
		branches[timeline] = logic
	}

	func switchTo(_ timeline: Timeline) {
		current = timeline
		Logger.log("🌐 Timeline switched to: \(timeline.rawValue)", log: Logger.general)
	}

	func run() {
		Logger.log("🧪 Executing timeline: \(current.rawValue)", log: Logger.general)
		if let branch = branches[current] {
			branch()
		} else {
			Logger.log("⚠️ No logic registered for timeline: \(current.rawValue)", type: .error, log: Logger.general)
		}
	}
}

// MARK: - CoreML Anomaly Detector

class TrafficAnomalyDetector {
	private let model: MLModel?
	
	enum ModelError: Error {
		case modelNotFound
		case invalidInput
		case predictionFailed(Error)
	}

	init(modelPath: String? = nil) {
		Logger.log("🧠 Initializing ML Anomaly Detector...", log: Logger.ml)
		let path: URL
		
		if let customPath = modelPath {
			path = URL(fileURLWithPath: customPath)
			Logger.log("   📍 Using custom model path: \(customPath)", log: Logger.ml)
		} else {
			// Try multiple common locations
			// First, try relative to executable location
			if let executablePath = Bundle.main.executablePath {
				let executableURL = URL(fileURLWithPath: executablePath)
				let projectRoot = executableURL.deletingLastPathComponent().deletingLastPathComponent() // Go up from build/bin/
				let defaultPath = projectRoot
					.appendingPathComponent("CompiledModel")
					.appendingPathComponent("AnomalyDetector.mlmodelc")
				path = defaultPath
				Logger.log("   📍 Using default model path: \(defaultPath.path)", log: Logger.ml)
			} else {
				// Fallback to current directory
				let currentDir = FileManager.default.currentDirectoryPath
				let defaultPath = URL(fileURLWithPath: currentDir)
					.appendingPathComponent("CompiledModel")
					.appendingPathComponent("AnomalyDetector.mlmodelc")
				path = defaultPath
				Logger.log("   📍 Using default model path: \(defaultPath.path)", log: Logger.ml)
			}
		}
		
		do {
			let loadedModel = try MLModel(contentsOf: path)
			self.model = loadedModel
			Logger.log("   ✅ ML model loaded successfully", log: Logger.ml)
			Logger.log("   📦 Model ready for anomaly detection", log: Logger.ml)
		} catch {
			Logger.log("   ⚠️  ML model not found or failed to load", log: Logger.ml)
			Logger.log("   📝 Error: \(error)", type: .error, log: Logger.ml)
			Logger.log("   💡 Defender will use threshold-based detection only", log: Logger.ml)
			self.model = nil
		}
	}
	
	var isAvailable: Bool {
		return model != nil
	}

	func isAnomalous(rate: Int) -> Bool {
		guard let model = model else {
			Logger.verbose("ML model not available, skipping anomaly detection", log: Logger.ml)
			return false
		}
		
		Logger.debug("Running ML prediction for rate: \(rate)", log: Logger.ml)
		
		guard let input = try? MLMultiArray(shape: [1], dataType: .int32) else {
			Logger.log("❌ Failed to create MLMultiArray input", type: .error, log: Logger.ml)
			Logger.debug("MLMultiArray creation failed for rate: \(rate)", log: Logger.ml)
			return false
		}
		input[0] = NSNumber(value: rate)
		
		Logger.debug("ML input created: [\(rate)]", log: Logger.ml)

		do {
			let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["input": input]))
			if let value = prediction.featureValue(for: "isAnomalous")?.int64Value {
				let isAnomaly = value == 1
				Logger.debug("ML prediction result: \(isAnomaly ? "ANOMALY" : "NORMAL") (value: \(value))", log: Logger.ml)
				return isAnomaly
			}
			Logger.debug("ML prediction returned nil value", log: Logger.ml)
		} catch {
			Logger.log("❌ CoreML prediction error: \(error)", type: .error, log: Logger.ml)
			Logger.debug("CoreML error details: \(error.localizedDescription)", log: Logger.ml)
		}
		return false
	}
}

// MARK: - Hammer4D Defender Core

class Hammer4DDefenderCore {
	var requestRate: TimeVariable<Int>
	lazy var detectionLogic: FunctionSwapper = FunctionSwapper(initialLogic: {
		Logger.log("🔍 Traffic normal.", log: Logger.traffic)
	})
	let realityFork = RealityFork()
	let mlDetector: TrafficAnomalyDetector
	private let config: DefenderConfig

	// Firewall related
	private var blockedIPs: Set<IPAddress> = []
	private let firewallQueue = DispatchQueue(label: "com.hammer4d.firewall", attributes: .concurrent)
	private var blockingInProgress = Set<IPAddress>()

	init(config: DefenderConfig = .default) {
		self.config = config
		self.requestRate = TimeVariable<Int>(initial: 0, maxHistorySize: config.maxHistorySize)
		self.mlDetector = TrafficAnomalyDetector(modelPath: config.mlModelPath)
		
		realityFork.register(.alpha) {
			Logger.log("🌱 Alpha Fork: Normalized behavior profile.", log: Logger.general)
		}
		realityFork.register(.omega) {
			Logger.log("🔥 Omega Fork: Polymorphic logic running...", log: Logger.general)
		}
	}

	func analyzeTraffic(rate: Int) {
		requestRate.value = rate
		
		Logger.debug("Analyzing traffic: rate=\(rate), history_size=\(requestRate.historyDump().count)", log: Logger.debug)
		
		// Enhanced traffic analysis output
		let mlResult = mlDetector.isAnomalous(rate: rate)
		let thresholdExceeded = rate > config.anomalyThreshold
		let isAnomalous = mlResult || thresholdExceeded
		
		Logger.debug("ML result: \(mlResult), threshold exceeded: \(thresholdExceeded), isAnomalous: \(isAnomalous)", log: Logger.debug)
		
		Logger.log("", log: Logger.traffic)
		Logger.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: Logger.traffic)
		Logger.log("📊 Traffic Analysis Report", log: Logger.traffic)
		Logger.log("   📈 Current Rate: \(rate) connections/sec", log: Logger.traffic)
		Logger.log("   🎯 Threshold: \(config.anomalyThreshold) connections/sec", log: Logger.traffic)
		
		if mlDetector.isAvailable {
			Logger.log("   🧠 ML Detection: \(mlResult ? "🚨 ANOMALY DETECTED" : "✅ Normal")", log: Logger.traffic)
		} else {
			Logger.log("   🧠 ML Detection: ⚠️  Model unavailable (using threshold only)", log: Logger.traffic)
		}
		
		Logger.log("   📉 Threshold Status: \(thresholdExceeded ? "🚨 EXCEEDED" : "✅ Within limits")", log: Logger.traffic)
		
		if isAnomalous {
			Logger.log("", log: Logger.traffic)
			Logger.log("🚨🚨🚨 ALERT: ANOMALOUS TRAFFIC DETECTED 🚨🚨🚨", type: .error, log: Logger.traffic)
			Logger.log("   ⚠️  Rate: \(rate)/sec (Threshold: \(config.anomalyThreshold)/sec)", type: .error, log: Logger.traffic)
			if mlResult {
				Logger.log("   🧠 ML Model flagged this as anomalous", type: .error, log: Logger.traffic)
			}
			if thresholdExceeded {
				Logger.log("   📊 Threshold exceeded by \(rate - config.anomalyThreshold) connections/sec", type: .error, log: Logger.traffic)
			}
			Logger.log("", log: Logger.traffic)
			
			requestRate.rewind()
			Logger.log("   🔄 Rewinding request rate to previous safe value", log: Logger.traffic)
			
			detectionLogic.mutate(newLogic: {
				Logger.log("   🛠️  Activating enhanced detection logic", log: Logger.general)
			})
			realityFork.switchTo(.omega)
			realityFork.run()
		} else {
			Logger.log("   ✅ Traffic is within normal parameters", log: Logger.traffic)
			Logger.log("   🌱 Maintaining normal operation mode", log: Logger.traffic)
			realityFork.switchTo(.alpha)
			detectionLogic.mutate(newLogic: {
				Logger.log("   🔍 Normal detection logic active", log: Logger.traffic)
			})
			realityFork.run()
		}
		Logger.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: Logger.traffic)
	}

	func isBlocked(ip: IPAddress) -> Bool {
		return firewallQueue.sync {
			blockedIPs.contains(ip)
		}
	}

	func block(ip: IPAddress) {
		// Prevent duplicate blocking attempts
		guard firewallQueue.sync(execute: { blockingInProgress.insert(ip).inserted }) else {
			Logger.log("⚠️  Block already in progress for \(ip.firewallFormat)", log: Logger.security)
			return
		}
		
		firewallQueue.async(flags: .barrier) { [weak self] in
			guard let self = self else { return }
			self.blockedIPs.insert(ip)
			
			Logger.log("", log: Logger.security)
			Logger.log("🔒━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: Logger.security)
			Logger.log("🚫 BLOCKING IP ADDRESS", log: Logger.security)
			Logger.log("   📍 IP: \(ip.firewallFormat)", log: Logger.security)
			Logger.log("   🌐 Version: IPv\(ip.version == .ipv4 ? "4" : "6")", log: Logger.security)
			Logger.log("   📊 Total blocked IPs: \(self.blockedIPs.count)", log: Logger.security)
			
			if self.config.enableFirewall {
				Logger.log("   🔥 Applying firewall rule...", log: Logger.security)
				self.executeFirewallBlock(ip: ip)
			} else {
				Logger.log("   ⚠️  Firewall disabled - IP added to blocklist only", log: Logger.security)
			}
			
			Logger.log("🔒━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: Logger.security)
			
			// Remove from in-progress set after a delay
			DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
				self.firewallQueue.async(flags: .barrier) {
					self.blockingInProgress.remove(ip)
				}
			}
		}
	}
	
	private func executeFirewallBlock(ip: IPAddress) {
		// Validate IP address (already validated, but double-check)
		guard IPAddress(ip.value) != nil else {
			Logger.log("❌ Invalid IP address format: \(ip)", type: .error, log: Logger.security)
			return
		}
		
		// Sanitize IP to prevent command injection
		// For IPv4: only allow digits and dots
		// For IPv6: allow hex digits, colons, and brackets
		let sanitizedIP: String
		switch ip.version {
		case .ipv4:
			sanitizedIP = ip.value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
			guard IPAddress(sanitizedIP) != nil && IPAddress(sanitizedIP)?.version == .ipv4 else {
				Logger.log("❌ Invalid IPv4 address after sanitization: \(ip)", type: .error, log: Logger.security)
				return
			}
		case .ipv6:
			// Remove brackets, sanitize, then add back if needed
			var cleaned = ip.value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
			cleaned = cleaned.replacingOccurrences(of: "[^0-9a-fA-F:.]", with: "", options: .regularExpression)
			guard IPAddress(cleaned) != nil && IPAddress(cleaned)?.version == .ipv6 else {
				Logger.log("❌ Invalid IPv6 address after sanitization: \(ip)", type: .error, log: Logger.security)
				return
			}
			sanitizedIP = cleaned
		}
		
		// Use Process with proper arguments instead of shell command
		let task = Process()
		task.launchPath = "/usr/bin/sudo"
		task.arguments = [
			"-n", // Non-interactive (assumes passwordless sudo configured)
			"/sbin/pfctl",
			"-a", config.firewallAnchor,
			"-f", "-"
		]
		
		let pipe = Pipe()
		task.standardInput = pipe
		task.standardOutput = Pipe()
		task.standardError = Pipe()
		
		do {
			try task.run()
			// Format firewall rule based on IP version
			// IPv6 addresses need brackets in pfctl rules
			let rule: String
			switch ip.version {
			case .ipv4:
				rule = "block drop from \(sanitizedIP) to any\n"
			case .ipv6:
				rule = "block drop from \(ip.firewallFormat) to any\n"
			}
			
			if let data = rule.data(using: .utf8) {
				pipe.fileHandleForWriting.write(data)
				pipe.fileHandleForWriting.closeFile()
			}
			task.waitUntilExit()
			
			if task.terminationStatus == 0 {
				Logger.log("   ✅ Firewall rule successfully applied", log: Logger.security)
				Logger.log("   📝 Rule: block drop from \(ip.firewallFormat) to any", log: Logger.security)
			} else {
				// Read error output for debugging
				let errorData = task.standardError as! Pipe
				let errorString = String(data: errorData.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
				Logger.log("   ❌ Firewall command failed!", type: .error, log: Logger.security)
				Logger.log("   📝 Exit status: \(task.terminationStatus)", type: .error, log: Logger.security)
				Logger.log("   📝 Error: \(errorString)", type: .error, log: Logger.security)
				Logger.log("   💡 Tip: Ensure sudo is configured for passwordless execution", type: .error, log: Logger.security)
			}
		} catch {
			Logger.log("❌ Failed to execute firewall command: \(error)", type: .error, log: Logger.security)
		}
	}
}

// MARK: - IP Extraction Helper

extension NWConnection {
	func extractRemoteIP() -> IPAddress? {
		if case let NWEndpoint.hostPort(host, _) = endpoint {
			switch host {
			case .ipv4(let ipv4):
				// Extract IPv4 address using Network framework
				// ipv4.rawValue is Data containing sockaddr_in structure
				return ipv4.rawValue.withUnsafeBytes { bytes -> IPAddress? in
					guard bytes.count >= MemoryLayout<sockaddr_in>.size else { return nil }
					let sockaddr = bytes.bindMemory(to: sockaddr_in.self).baseAddress!.pointee
					var addr = sockaddr.sin_addr
					var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
					if inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
						let ipString = String(cString: buffer)
						return IPAddress(ipString)
					}
					return nil
				}
			case .ipv6(let ipv6):
				// Extract IPv6 address using Network framework
				// ipv6.rawValue is Data containing sockaddr_in6 structure
				return ipv6.rawValue.withUnsafeBytes { bytes -> IPAddress? in
					guard bytes.count >= MemoryLayout<sockaddr_in6>.size else { return nil }
					let sockaddr = bytes.bindMemory(to: sockaddr_in6.self).baseAddress!.pointee
					var addr = sockaddr.sin6_addr
					var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
					if inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN)) != nil {
						let ipString = String(cString: buffer)
						if let ip = IPAddress(ipString) {
							Logger.log("✅ IPv6 address extracted: \(ipString)", log: Logger.security)
							return ip
						} else {
							Logger.log("⚠️ Failed to validate IPv6 address: \(ipString)", log: Logger.security)
							return nil
						}
					}
					return nil
				}
			case .name(let name, _):
				// Hostname - would need DNS resolution in production
				Logger.log("⚠️ Hostname detected: \(name) - IP extraction requires DNS resolution", log: Logger.security)
				return nil
			@unknown default:
				return nil
			}
		}
		return nil
	}
}

// MARK: - TCP Listener for Multiple Selected Ports with SSH Banner mimicry

class TCPListener {
	private let ports: [UInt16]
	private var listeners: [NWListener] = []
	private var connectionCounts: [UInt16: Int] = [:]
	private let connectionCountsQueue = DispatchQueue(label: "com.hammer4d.connections", attributes: .concurrent)
	private let defender: Hammer4DDefenderCore
	private var timer: DispatchSourceTimer?
	private var isRunning = false

	init(defender: Hammer4DDefenderCore, ports: [UInt16]) {
		self.defender = defender
		self.ports = ports
	}

	func start() throws {
		guard !isRunning else {
			Logger.log("⚠️ Listener already running", log: Logger.general)
			return
		}
		
		isRunning = true
		
		for port in ports {
			guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
				Logger.log("❌ Invalid port number: \(port)", type: .error, log: Logger.general)
				continue
			}
			
			do {
				let listener = try NWListener(using: .tcp, on: endpointPort)
				connectionCountsQueue.async(flags: .barrier) {
					self.connectionCounts[port] = 0
				}

				listener.stateUpdateHandler = { state in
					switch state {
					case .ready:
						Logger.log("   ✅ Port \(port) is now LISTENING", log: Logger.general)
						Logger.log("      🎯 Ready to accept connections", log: Logger.general)
					case .failed(let error):
						Logger.log("❌ Listener on port \(port) failed: \(error)", type: .error, log: Logger.general)
					case .cancelled:
						Logger.log("🛑 Listener on port \(port) cancelled", log: Logger.general)
					default:
						break
					}
				}

				listener.newConnectionHandler = { [weak self] connection in
					guard let self = self, self.isRunning else {
						connection.cancel()
						return
					}

					// Extract IP address properly
					guard let remoteIP = connection.extractRemoteIP() else {
						Logger.log("⚠️  Could not extract IP from connection, rejecting", log: Logger.security)
						connection.cancel()
						return
					}

					if self.defender.isBlocked(ip: remoteIP) {
						Logger.log("", log: Logger.security)
						Logger.log("⛔ BLOCKED CONNECTION ATTEMPT", log: Logger.security)
						Logger.log("   🚫 IP: \(remoteIP.firewallFormat) (IPv\(remoteIP.version == .ipv4 ? "4" : "6"))", log: Logger.security)
						Logger.log("   🔌 Port: \(port)", log: Logger.security)
						Logger.log("   ❌ Connection rejected", log: Logger.security)
						connection.cancel()
						return
					}

					Logger.log("🔗 New connection: \(remoteIP.firewallFormat) → port \(port)", log: Logger.traffic)

					self.connectionCountsQueue.async(flags: .barrier) {
						self.connectionCounts[port, default: 0] += 1
					}

					self.handleConnection(connection, port: port, remoteIP: remoteIP)
				}

				listener.start(queue: .global())
				listeners.append(listener)
			} catch {
				Logger.log("❌ Failed to create listener on port \(port): \(error)", type: .error, log: Logger.general)
				throw error
			}
		}

		timer = DispatchSource.makeTimerSource(queue: .global())
		timer?.schedule(deadline: .now() + 1, repeating: 1)
		timer?.setEventHandler { [weak self] in
			guard let self = self, self.isRunning else { return }
			
			let totalConnections = self.connectionCountsQueue.sync {
				let total = self.connectionCounts.values.reduce(0, +)
				let perPort = self.connectionCounts.map { "port \($0.key): \($0.value)" }.joined(separator: ", ")
				let details = self.connectionCounts
				self.connectionCounts.removeAll()
				return (total, perPort, details)
			}
			
			Logger.debug("Timer tick: total=\(totalConnections.0), details=\(totalConnections.2)", log: Logger.debug)
			
			Logger.log("", log: Logger.traffic)
			Logger.log("⏱️  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: Logger.traffic)
			Logger.log("📊 Connection Statistics (Last Second)", log: Logger.traffic)
			Logger.log("   🔢 Total: \(totalConnections.0) connections", log: Logger.traffic)
			if !totalConnections.1.isEmpty {
				Logger.log("   📍 Per Port: \(totalConnections.1)", log: Logger.traffic)
			}
			Logger.verbose("Detailed breakdown: \(totalConnections.2)", log: Logger.debug)
			Logger.log("⏱️  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", log: Logger.traffic)
			self.defender.analyzeTraffic(rate: totalConnections.0)
		}
		timer?.resume()
	}

	func handleConnection(_ connection: NWConnection, port: UInt16, remoteIP: IPAddress) {
		connection.stateUpdateHandler = { [weak self] state in
			guard let self = self, self.isRunning else {
				connection.cancel()
				return
			}
			
			switch state {
			case .ready:
				// Send SSH banner mimic on ready connection
				let banner = "SSH-2.0-OpenSSH_7.9p1 Debian-10+deb9u2\r\n"
				guard let bannerData = banner.data(using: .utf8) else {
					Logger.log("❌ Failed to encode SSH banner", type: .error, log: Logger.general)
					connection.cancel()
					return
				}
				
				connection.send(content: bannerData, completion: .contentProcessed({ error in
					if let error = error {
						Logger.log("   ❌ Error sending SSH banner: \(error)", type: .error, log: Logger.general)
					} else {
						Logger.log("   🎭 Sent SSH-2.0 banner to \(remoteIP.firewallFormat) (honeypot response)", log: Logger.traffic)
					}
					connection.cancel() // Close after sending banner to mimic SSH
				}))
			case .failed(let error):
				Logger.log("❌ Connection on port \(port) from \(remoteIP) failed: \(error)", type: .error, log: Logger.general)
			case .cancelled:
				break
			default:
				break
			}
		}
		connection.start(queue: .global())
	}

	func stop() {
		guard isRunning else { return }
		
		isRunning = false
		listeners.forEach { $0.cancel() }
		listeners.removeAll()
		timer?.cancel()
		timer = nil
		
		connectionCountsQueue.sync(flags: .barrier) {
			connectionCounts.removeAll()
		}
		
		Logger.log("", log: Logger.general)
		Logger.log("╔════════════════════════════════════════════════════════════════╗", log: Logger.general)
		Logger.log("║  🛑 DEFENDER SHUTDOWN COMPLETE                                ║", log: Logger.general)
		Logger.log("╚════════════════════════════════════════════════════════════════╝", log: Logger.general)
		Logger.log("   ✅ All listeners stopped", log: Logger.general)
		Logger.log("   ✅ Timers cancelled", log: Logger.general)
		Logger.log("   ✅ Resources cleaned up", log: Logger.general)
		Logger.log("", log: Logger.general)
	}
}

// MARK: - Signal Handler for Graceful Shutdown

var globalListener: TCPListener?

signal(SIGINT) { _ in
	Logger.log("", log: Logger.general)
	Logger.log("╔════════════════════════════════════════════════════════════════╗", log: Logger.general)
	Logger.log("║  🛑 SHUTDOWN SIGNAL RECEIVED (SIGINT)                            ║", log: Logger.general)
	Logger.log("╚════════════════════════════════════════════════════════════════╝", log: Logger.general)
	Logger.log("   ⏳ Initiating graceful shutdown...", log: Logger.general)
	globalListener?.stop()
	exit(0)
}

signal(SIGTERM) { _ in
	Logger.log("", log: Logger.general)
	Logger.log("╔════════════════════════════════════════════════════════════════╗", log: Logger.general)
	Logger.log("║  🛑 SHUTDOWN SIGNAL RECEIVED (SIGTERM)                          ║", log: Logger.general)
	Logger.log("╚════════════════════════════════════════════════════════════════╝", log: Logger.general)
	Logger.log("   ⏳ Initiating graceful shutdown...", log: Logger.general)
	globalListener?.stop()
	exit(0)
}

// MARK: - Main

func main() {
	// Check for debug mode from environment or arguments
	let isDebugMode = ProcessInfo.processInfo.environment["DEBUG"] == "1" || 
	                 CommandLine.arguments.contains("--debug") ||
	                 CommandLine.arguments.contains("-d")
	let isVerboseMode = ProcessInfo.processInfo.environment["VERBOSE"] == "1" ||
	                   CommandLine.arguments.contains("--verbose") ||
	                   CommandLine.arguments.contains("-v")
	let noClearScreen = CommandLine.arguments.contains("--no-clear") ||
	                   ProcessInfo.processInfo.environment["NO_CLEAR"] == "1"
	
	Logger.setClearScreen(!noClearScreen)
	
	Logger.log("", log: Logger.general)
	Logger.log("╔════════════════════════════════════════════════════════════════╗", log: Logger.general)
	Logger.log("║  🛡️  Hammer4D Firewall Defender - Advanced DDoS Protection    ║", log: Logger.general)
	if isDebugMode {
		Logger.log("║  🐛 DEBUG MODE ENABLED                                        ║", log: Logger.general)
	}
	if isVerboseMode {
		Logger.log("║  🔍 VERBOSE MODE ENABLED                                      ║", log: Logger.general)
	}
	Logger.log("╚════════════════════════════════════════════════════════════════╝", log: Logger.general)
	Logger.log("", log: Logger.general)
	
	let config: DefenderConfig
	if isDebugMode || isVerboseMode {
		config = DefenderConfig.debug()
		Logger.log("🐛 Debug mode: Firewall disabled for safety", log: Logger.general)
	} else {
		config = DefenderConfig.default
	}
	
	Logger.log("📋 Configuration:", log: Logger.general)
	Logger.log("   🔌 Ports: \(config.ports.map { String($0) }.joined(separator: ", "))", log: Logger.general)
	Logger.log("   📊 Anomaly Threshold: \(config.anomalyThreshold) connections/sec", log: Logger.general)
	Logger.log("   🔥 Firewall: \(config.enableFirewall ? "✅ Enabled" : "❌ Disabled")", log: Logger.general)
	Logger.log("   📚 History Size: \(config.maxHistorySize) entries", log: Logger.general)
	Logger.log("   🐛 Debug Mode: \(config.debugMode ? "✅ Enabled" : "❌ Disabled")", log: Logger.general)
	Logger.log("   🔍 Verbose Logging: \(config.verboseLogging ? "✅ Enabled" : "❌ Disabled")", log: Logger.general)
	Logger.log("", log: Logger.general)
	
	if config.debugMode {
		Logger.debug("Process ID: \(ProcessInfo.processInfo.processIdentifier)", log: Logger.debug)
		Logger.debug("Arguments: \(CommandLine.arguments.joined(separator: " "))", log: Logger.debug)
		Logger.debug("Environment: DEBUG=\(ProcessInfo.processInfo.environment["DEBUG"] ?? "not set")", log: Logger.debug)
	}
	
	Logger.log("🚀 Initializing components...", log: Logger.general)
	let defender = Hammer4DDefenderCore(config: config)
	let tcpListener = TCPListener(defender: defender, ports: config.ports)
	globalListener = tcpListener
	
	Logger.log("   ✅ Defender core initialized", log: Logger.general)
	Logger.log("   ✅ TCP listener created", log: Logger.general)
	Logger.log("", log: Logger.general)
	
	do {
		Logger.log("🎯 Starting listeners...", log: Logger.general)
		try tcpListener.start()
		Logger.log("", log: Logger.general)
		Logger.log("╔════════════════════════════════════════════════════════════════╗", log: Logger.general)
		Logger.log("║  ✅ Defender is now ACTIVE and monitoring traffic             ║", log: Logger.general)
		Logger.log("║  📡 Listening for connections on configured ports             ║", log: Logger.general)
		Logger.log("║  🧠 ML anomaly detection: \(defender.mlDetector.isAvailable ? "✅ Active" : "⚠️  Unavailable")", log: Logger.general)
		Logger.log("║  🌐 Timeline: \(defender.realityFork.current.rawValue.uppercased())", log: Logger.general)
		Logger.log("╚════════════════════════════════════════════════════════════════╝", log: Logger.general)
		Logger.log("", log: Logger.general)
		Logger.log("💡 Press Ctrl+C to stop gracefully", log: Logger.general)
		Logger.log("", log: Logger.general)
	} catch {
		Logger.log("", log: Logger.general)
		Logger.log("╔════════════════════════════════════════════════════════════════╗", log: Logger.general)
		Logger.log("║  ❌ FAILED TO START DEFENDER                                   ║", log: Logger.general)
		Logger.log("╚════════════════════════════════════════════════════════════════╝", log: Logger.general)
		Logger.log("   Error: \(error)", type: .fault, log: Logger.general)
		exit(1)
	}

	RunLoop.main.run()
}

main()