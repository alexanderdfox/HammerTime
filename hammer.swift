import Foundation
import Network

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

// MARK: - Hammer4D Defender Core

class Hammer4DDefenderCore {
	var requestRate = TimeVariable<Int>(initial: 0)
	
	lazy var detectionLogic: FunctionSwapper = FunctionSwapper(initialLogic: {
		print("🔍 Traffic normal.")
	})
	
	let realityFork = RealityFork()
	
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
		
		if rate > 200 {
			print("🚨 High traffic detected!")
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
}

// MARK: - TCP Listener for Real Network Input

class TCPListener {
	private let port: NWEndpoint.Port = 8080
	private var listener: NWListener?
	private var connectionCountThisSecond = 0
	private var defender: Hammer4DDefenderCore
	private var timer: DispatchSourceTimer?

	init(defender: Hammer4DDefenderCore) {
		self.defender = defender
	}

	func start() {
		do {
			listener = try NWListener(using: .tcp, on: port)
		} catch {
			print("❌ Failed to create listener: \(error)")
			return
		}
		
		listener?.stateUpdateHandler = { state in
			switch state {
			case .ready:
				print("📡 Listening on TCP port \(self.port)...")
			case .failed(let error):
				print("❌ Listener failed with error: \(error)")
				self.stop()
			default:
				break
			}
		}

		listener?.newConnectionHandler = { [weak self] connection in
			guard let self = self else { return }
			self.connectionCountThisSecond += 1
			self.handleConnection(connection)
		}

		listener?.start(queue: .main)

		// Timer fires every second to analyze connection count
		timer = DispatchSource.makeTimerSource(queue: .main)
		timer?.schedule(deadline: .now() + 1, repeating: 1)
		timer?.setEventHandler { [weak self] in
			guard let self = self else { return }
			let rate = self.connectionCountThisSecond
			self.connectionCountThisSecond = 0
			print("\n⏱️ Second:")
			self.defender.analyzeTraffic(rate: rate)
		}
		timer?.resume()
	}

	func handleConnection(_ connection: NWConnection) {
		connection.stateUpdateHandler = { state in
			switch state {
			case .ready:
				// Optionally handle connection reads/writes here
				break
			case .failed(let error):
				print("❌ Connection failed: \(error)")
			case .cancelled:
				break
			default:
				break
			}
		}
		connection.start(queue: .main)
	}

	func stop() {
		listener?.cancel()
		timer?.cancel()
		print("🛑 Listener stopped.")
	}
}

// MARK: - Main

func main() {
	print("=== 🛡 Hammer4D Defender v3 with real network input ===")
	
	let defender = Hammer4DDefenderCore()
	let tcpListener = TCPListener(defender: defender)
	
	tcpListener.start()
	
	RunLoop.main.run()
}

main()