//
//  DevelopmentBookmarkService+ResourceMonitoring.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Extension containing resource monitoring functionality for DevelopmentBookmarkService
@available(macOS 13.0, *)
extension DevelopmentBookmarkService {
    /// Monitors resource usage for the service
    final class ResourceMonitor: CustomStringConvertible {
        private var usage: ResourceUsage = .zero
        private let queue = DispatchQueue(label: "dev.mpy.rBUM.resourceMonitor")
        
        struct ResourceUsage {
            var memory: UInt64 = 0
            var cpu: Double = 0
            var fileDescriptors: Int = 0
            
            static let zero = ResourceUsage()
        }
        
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
                self.usage.memory = UInt64.random(in: 1_000_000...100_000_000)
                self.usage.cpu = Double.random(in: 0...100)
                self.usage.fileDescriptors = Int.random(in: 0...1000)
            }
        }
    }
    
    /// Performance tracking for the service
    final class PerformanceTracker: CustomStringConvertible {
        private var metrics: [String: TimeInterval] = [:]
        private let queue = DispatchQueue(label: "dev.mpy.rBUM.performanceTracker")
        
        var currentMetrics: [String: TimeInterval] {
            queue.sync { metrics }
        }
        
        var description: String {
            let metrics = currentMetrics
            return metrics.map { "\($0.key): \($0.value)s" }.joined(separator: "\n")
        }
        
        func recordMetrics() {
            queue.async {
                // Simulate performance metrics
                self.metrics["bookmarkCreation"] = TimeInterval.random(in: 0.001...0.1)
                self.metrics["bookmarkResolution"] = TimeInterval.random(in: 0.001...0.05)
                self.metrics["bookmarkValidation"] = TimeInterval.random(in: 0.001...0.03)
            }
        }
    }
    
    /// Check if resource usage exceeds configured limits
    func checkResourceLimits() {
        let usage = resourceMonitor.currentUsage
        let limits = configuration.resourceLimits
        
        if usage.memory > limits.memory {
            logger.warning(
                "Memory usage exceeds limit: \(usage.memory) > \(limits.memory)",
                file: #file,
                function: #function,
                line: #line
            )
        }
        
        if usage.cpu > limits.cpu {
            logger.warning(
                "CPU usage exceeds limit: \(usage.cpu)% > \(limits.cpu)%",
                file: #file,
                function: #function,
                line: #line
            )
        }
        
        if usage.fileDescriptors > limits.fileDescriptors {
            logger.warning(
                "File descriptor usage exceeds limit: \(usage.fileDescriptors) > \(limits.fileDescriptors)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
}
