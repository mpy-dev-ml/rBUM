//
//  DevelopmentBookmarkService+Metrics.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

import Foundation

// MARK: - Metrics Extension

@available(macOS 13.0, *)
extension DevelopmentBookmarkService {
    /// Tracks metrics for bookmark operations
    struct BookmarkMetrics: Codable {
        var totalBookmarks: Int = 0
        var totalValidations: Int = 0
        var totalAccesses: Int = 0
        var averageValidationTime: TimeInterval = 0
        var averageAccessTime: TimeInterval = 0
        var failedValidations: Int = 0
        var failedAccesses: Int = 0
        var resourceUsage: ResourceUsage = .zero
        
        static var zero: BookmarkMetrics {
            BookmarkMetrics()
        }
    }
    
    /// Resource usage metrics
    struct ResourceUsage: Codable {
        var memoryUsage: Int = 0
        var diskUsage: Int = 0
        var cpuUsage: Double = 0
        
        static var zero: ResourceUsage {
            ResourceUsage()
        }
    }
    
    /// Monitor for tracking resource usage
    final class ResourceMonitor: CustomStringConvertible {
        private var usage: ResourceUsage = .zero
        private let queue = DispatchQueue(label: "dev.mpy.rBUM.resourceMonitor")
        
        var description: String {
            "ResourceMonitor(memory: \(usage.memoryUsage) bytes, disk: \(usage.diskUsage) bytes, cpu: \(usage.cpuUsage)%)"
        }
        
        func update(memoryUsage: Int? = nil, diskUsage: Int? = nil, cpuUsage: Double? = nil) {
            queue.sync {
                if let memoryUsage = memoryUsage {
                    usage.memoryUsage = memoryUsage
                }
                if let diskUsage = diskUsage {
                    usage.diskUsage = diskUsage
                }
                if let cpuUsage = cpuUsage {
                    usage.cpuUsage = cpuUsage
                }
            }
        }
        
        func currentUsage() -> ResourceUsage {
            queue.sync { usage }
        }
    }
    
    /// Collect and update metrics
    func collectMetrics() {
        guard configuration.shouldCollectMetrics else { return }
        
        withThreadSafety {
            // Update performance metrics
            metrics.totalBookmarks = bookmarks.count
            
            // Update resource metrics
            let totalSize = bookmarks.values.reduce(0) { $0 + $1.data.count }
            resourceMonitor.update(
                memoryUsage: Int(ProcessInfo.processInfo.physicalFootprint),
                diskUsage: totalSize,
                cpuUsage: ProcessInfo.processInfo.systemUptime
            )
            
            metrics.resourceUsage = resourceMonitor.currentUsage()
        }
    }
}
