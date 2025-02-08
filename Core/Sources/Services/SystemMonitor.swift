//
//  SystemMonitor.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//
import Foundation

/// Protocol for monitoring system resources
@objc public protocol SystemMonitorProtocol {
    /// Check system resources
    /// - Returns: Current system resource state
    func checkResources() async throws -> SystemResources
}

/// System resource state
@objc public class SystemResources: NSObject {
    /// Available memory in bytes
    @objc public let memoryAvailable: UInt64
    
    /// Total memory in bytes
    @objc public let memoryTotal: UInt64
    
    /// CPU usage percentage (0-100)
    @objc public let cpuUsage: Double
    
    /// Initialize system resources
    /// - Parameters:
    ///   - memoryAvailable: Available memory in bytes
    ///   - memoryTotal: Total memory in bytes
    ///   - cpuUsage: CPU usage percentage
    @objc public init(
        memoryAvailable: UInt64,
        memoryTotal: UInt64,
        cpuUsage: Double
    ) {
        self.memoryAvailable = memoryAvailable
        self.memoryTotal = memoryTotal
        self.cpuUsage = cpuUsage
        super.init()
    }
}

/// Default implementation of system monitor
public final class SystemMonitor: SystemMonitorProtocol {
    // MARK: - Properties
    
    private let host: host_t
    private let machHost: mach_port_t
    
    // MARK: - Initialization
    
    public init() {
        self.host = mach_host_self()
        self.machHost = mach_host_self()
    }
    
    // MARK: - SystemMonitorProtocol
    
    public func checkResources() async throws -> SystemResources {
        // Get memory statistics
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = vm_statistics64_data_t()
        
        let result = withUnsafeMutablePointer(to: &hostInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) { pointer in
                host_statistics64(machHost, HOST_VM_INFO64, pointer, &hostSize)
            }
        }
        
        guard result == KERN_SUCCESS else {
            throw SystemMonitorError.failedToGetMemoryStats
        }
        
        // Calculate memory values
        let pageSize = UInt64(vm_kernel_page_size)
        let memoryAvailable = UInt64(hostInfo.free_count) * pageSize
        let memoryTotal = ProcessInfo.processInfo.physicalMemory
        
        // Get CPU usage
        let cpuUsage = try await getCPUUsage()
        
        return SystemResources(
            memoryAvailable: memoryAvailable,
            memoryTotal: memoryTotal,
            cpuUsage: cpuUsage
        )
    }
    
    // MARK: - Private
    
    private func getCPUUsage() async throws -> Double {
        var cpuLoad = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics(host, HOST_CPU_LOAD_INFO, pointer, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            throw SystemMonitorError.failedToGetCPUStats
        }
        
        let totalTicks = cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3
        let idleTicks = cpuLoad.cpu_ticks.3
        
        return Double(totalTicks - idleTicks) / Double(totalTicks) * 100.0
    }
}

/// Errors that can occur during system monitoring
public enum SystemMonitorError: LocalizedError {
    case failedToGetMemoryStats
    case failedToGetCPUStats
    
    public var errorDescription: String? {
        switch self {
        case .failedToGetMemoryStats:
            return "Failed to get memory statistics"
        case .failedToGetCPUStats:
            return "Failed to get CPU statistics"
        }
    }
}
