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
        guard let url = Bundle.main.url(forResource: "TrafficAnomalyClassifier", withExtension: "mlmodelc"),
              let loadedModel = try? MLModel(contentsOf: url) else {
            print("❌ Failed to load ML model.")
            return nil
        }
        self.model = loadedModel
    }

    func isAnomalous(rate: Int) -> Bool {
        guard let input = try? MLMultiArray(shape: [1], dataType: .int32) else {
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
}

// MARK: - TCP Listener for Real Network Input

class TCPListener {
    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private var connectionCountThisSecond = 0
    private var defender: Hammer4DDefenderCore
    private var timer: DispatchSourceTimer?

    init(port: UInt16, defender: Hammer4DDefenderCore) {
        self.port = NWEndpoint.Port(rawValue: port)!
        self.defender = defender
    }

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("❌ Failed to create listener on port \(port): \(error)")
            return
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("📡 Listening on TCP port \(self.port)...")
            case .failed(let error):
                print("❌ Listener failed on port \(self.port): \(error)")
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

        timer = DispatchSource.makeTimerSource(queue: .main)
        timer?.schedule(deadline: .now() + 1, repeating: 1)
        timer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            let rate = self.connectionCountThisSecond
            self.connectionCountThisSecond = 0
            print("\n⏱️ Port \(self.port) second tick:")
            self.defender.analyzeTraffic(rate: rate)
        }
        timer?.resume()
    }

    func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
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
        print("🛑 Listener stopped on port \(port).")
    }
}

// MARK: - Main

func main() {
    print("=== 🛡 Hammer4D Defender v4 with CoreML Anomaly Detection ===")

    let ports: [UInt16]
    if CommandLine.arguments.count > 1 {
        ports = CommandLine.arguments.dropFirst().compactMap { UInt16($0) }
    } else {
        ports = [8080, 8081, 9090] // Default ports
    }

    var listeners: [TCPListener] = []

    for port in ports {
        let defender = Hammer4DDefenderCore()
        let listener = TCPListener(port: port, defender: defender)
        listener.start()
        listeners.append(listener)
    }

    dispatchMain() // Keep the main thread alive
}

main()
