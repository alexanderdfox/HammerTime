import Foundation
import Network
import CoreML

// MARK: - Temporal Variable Tracker

class TimeVariable<T> {
	private var history: [T] = []

	var value: T {
		didSet {
			history.append(value)
		}
	}

	init(initial: T) {
		self.value = initial
		history.append(initial)
	}

	func rewind(by steps: Int = 1) {
		let index = max(0, history.count - steps - 1)
		value = history[index]
		print("🔄 Rewound value to: \(value)")
	}

	func historyDump() -> [T] {
		return history
	}
}

// MARK: - Logic Mutation (Function Swapping)

class FunctionSwapper {
	private var logic: () -> Void

	init(initialLogic: @escaping () -> Void) {
		self.logic = initialLogic
	}

	func run() {
		logic()
	}

	func mutate(newLogic: @escaping () -> Void) {
		print("🛠️ Logic mutated!")
		logic = newLogic
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
		print("🌐 Timeline switched to: \(timeline.rawValue)")
	}

	func run() {
		print("🧪 Executing timeline: \(current.rawValue)")
		if let branch = branches[current] {
			branch()
		} else {
			print("⚠️ No logic registered for timeline: \(current.rawValue)")
		}
	}
}

// MARK: - CoreML Anomaly Detector

class TrafficAnomalyDetector {
	private let model: MLModel

	init?() {
		// Load compiled model from relative folder (adjust path as needed)
		let currentDir = FileManager.default.currentDirectoryPath
		let modelPath = URL(fileURLWithPath: currentDir)
			.appendingPathComponent("CompiledModel")
			.appendingPathComponent("AnomalyDetector.mlmodelc")

		guard let loadedModel = try? MLModel(contentsOf: modelPath) else {
			print("❌ Failed to load compiled ML model at \(modelPath.path).")
			return nil
		}
		self.model = loadedModel
	}

	func isAnomalous(rate: Int) -> Bool {
		guard let input = try? MLMultiArray(shape: [1], dataType: .int32) else {
			print("❌ Failed to create MLMultiArray input.")
			return false
		}
		input[0] = NSNumber(value: rate)

		do {
			let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["input": input]))
			if let value = prediction.featureValue(for: "isAnomalous")?.int64Value {
				return value == 1
			}
		} catch {
			print("❌ CoreML prediction error: \(error)")
		}
		return false
	}
}

// MARK: - Hammer4D Defender Core

class Hammer4DDefenderCore {
	var requestRate = TimeVariable<Int>(initial: 0)
	lazy var detectionLogic: FunctionSwapper = FunctionSwapper(initialLogic: {
		print("🔍 Traffic normal.")
	})
	let realityFork = RealityFork()
	let mlDetector = TrafficAnomalyDetector()

	// Firewall related
	private var blockedIPs: Set<String> = []
	private let queue = DispatchQueue(label: "com.hammer4d.firewall", attributes: .concurrent)

	init() {
		realityFork.register(.alpha) {
			print("🌱 Alpha Fork: Normalized behavior profile.")
		}
		realityFork.register(.omega) {
			print("🔥 Omega Fork: Polymorphic logic running...")
		}
	}

	func analyzeTraffic(rate: Int) {
		requestRate.value = rate
		print("📈 Request Rate: \(rate)/sec")

		if mlDetector?.isAnomalous(rate: rate) == true || rate > 200 {
			print("🚨 Anomaly or High traffic detected!")
			requestRate.rewind()
			detectionLogic.mutate(newLogic: {
				print("🧠 Detection logic mutated!")
			})
			realityFork.switchTo(.omega)
			realityFork.run()
		} else {
			realityFork.switchTo(.alpha)
			detectionLogic.mutate(newLogic: {
				print("🔍 Traffic normal.")
			})
			realityFork.run()
		}
	}

	func isBlocked(ip: String) -> Bool {
		var result = false
		queue.sync {
			result = blockedIPs.contains(ip)
		}
		return result
	}

	func block(ip: String) {
		_ = queue.sync { blockedIPs.insert(ip) }
		print("🚫 Blocked IP: \(ip)")
		let command = "echo 'block drop from \(ip) to any' | sudo pfctl -a com.hammer4d -f -"
		shell(command)
	}
}

// MARK: - Shell helper

@discardableResult
func shell(_ command: String) -> Int32 {
	let task = Process()
	task.launchPath = "/bin/bash"
	task.arguments = ["-c", command]
	task.launch()
	task.waitUntilExit()
	return task.terminationStatus
}

// MARK: - TCP Listener for Multiple Selected Ports with SSH Banner mimicry

class TCPListener {
	private let ports: [UInt16]
	private var listeners: [NWListener] = []
	private var connectionCounts: [UInt16: Int] = [:]
	private let defender: Hammer4DDefenderCore
	private var timer: DispatchSourceTimer?

	init(defender: Hammer4DDefenderCore, ports: [UInt16]) {
		self.defender = defender
		self.ports = ports
	}

	func start() {
		for port in ports {
			do {
				let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
				connectionCounts[port] = 0

				listener.stateUpdateHandler = { state in
					switch state {
					case .ready:
						print("📡 Listening on TCP port \(port)...")
					case .failed(let error):
						print("❌ Listener on port \(port) failed: \(error)")
					default:
						break
					}
				}

				listener.newConnectionHandler = { [weak self] connection in
					guard let self = self else { return }

					// Extract IP address string (approximate)
					var remoteIP = "unknown"
					if case let NWEndpoint.hostPort(host, _) = connection.endpoint {
						remoteIP = host.debugDescription
					}

					if self.defender.isBlocked(ip: remoteIP) {
						print("⛔ Connection from blocked IP \(remoteIP) rejected.")
						connection.cancel()
						return
					}

					self.connectionCounts[port, default: 0] += 1

					self.handleConnection(connection, port: port, remoteIP: remoteIP)
				}

				listener.start(queue: .global())
				listeners.append(listener)
			} catch {
				print("❌ Failed to create listener on port \(port): \(error)")
			}
		}

		timer = DispatchSource.makeTimerSource(queue: .global())
		timer?.schedule(deadline: .now() + 1, repeating: 1)
		timer?.setEventHandler { [weak self] in
			guard let self = self else { return }
			let totalConnections = self.connectionCounts.values.reduce(0, +)
			self.connectionCounts = [:]
			print("\n⏱️ Total connections last second: \(totalConnections)")
			self.defender.analyzeTraffic(rate: totalConnections)
		}
		timer?.resume()
	}

	func handleConnection(_ connection: NWConnection, port: UInt16, remoteIP: String) {
		connection.stateUpdateHandler = { state in
			switch state {
			case .ready:
				// Send SSH banner mimic on ready connection
				let banner = "SSH-2.0-OpenSSH_7.9p1 Debian-10+deb9u2\r\n"
				connection.send(content: banner.data(using: .utf8), completion: .contentProcessed({ error in
					if let error = error {
						print("❌ Error sending banner: \(error)")
					}
					connection.cancel() // Close after sending banner to mimic SSH
				}))
			case .failed(let error):
				print("❌ Connection on port \(port) failed: \(error)")
			case .cancelled:
				break
			default:
				break
			}
		}
		connection.start(queue: .global())
	}

	func stop() {
		listeners.forEach { $0.cancel() }
		timer?.cancel()
		print("🛑 All listeners stopped.")
	}
}

// MARK: - Main

func main() {
	print("=== 🛡 Hammer4D Firewall Defender with SSH mimic on selected ports ===")

	// You can change this array to any list of ports you want to monitor
	let selectedPorts: [UInt16] = [22, 80, 443, 2222]

	let defender = Hammer4DDefenderCore()
	let tcpListener = TCPListener(defender: defender, ports: selectedPorts)
	tcpListener.start()

	RunLoop.main.run()
}

main()
