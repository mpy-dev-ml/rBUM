import Foundation

/// Monitors resource usage for the service
@available(macOS 13.0, *)
final class ResourceMonitor: CustomStringConvertible {
    private var usage: ResourceUsage = .zero
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.resourceMonitor")

    var currentUsage: ResourceUsage {
        queue.sync { usage }
    }

    var description: String {
        let usage = currentUsage
        return """
        Memory: \(usage.memory) bytes
        CPU: \(usage.cpu)%
        File Descriptors: \(usage.fileDescriptors)
        """
    }

    func updateResourceUsage() {
        queue.async {
            // Simulate resource usage changes
            self.usage.memory = UInt64.random(in: 1_000_000 ... 100_000_000)
            self.usage.cpu = Double.random(in: 0 ... 100)
            self.usage.fileDescriptors = Int.random(in: 0 ... 1000)
        }
    }
}
