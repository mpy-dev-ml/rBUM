import Foundation

/// Performance tracking for the service
@available(macOS 13.0, *)
final class PerformanceTracker: CustomStringConvertible {
    private var metrics: [String: TimeInterval] = [:]
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.performanceTracker")

    var description: String {
        queue.sync {
            metrics.map { "\($0.key): \($0.value)s" }.joined(separator: "\n")
        }
    }

    func recordOperation(_ name: String, duration: TimeInterval) {
        queue.async {
            self.metrics[name] = duration
        }
    }

    func clearMetrics() {
        queue.async {
            self.metrics.removeAll()
        }
    }
}
