//
//  SystemResources.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Foundation

/// A class that encapsulates system resource information.
///
/// This class provides information about:
/// - Available memory
/// - Available disk space
/// - CPU usage
/// - System load
///
/// Example usage:
/// ```swift
/// let resources = SystemResources(
///     availableMemory: 8_589_934_592,  // 8 GB
///     availableDiskSpace: 107_374_182_400,  // 100 GB
///     cpuUsagePercentage: 45.5,
///     systemLoad: [1.5, 1.2, 1.0]
/// )
/// ```
@objc public class SystemResources: NSObject, NSSecureCoding {
    // MARK: - Properties
    
    /// Available system memory in bytes
    @objc public let availableMemory: UInt64
    
    /// Available disk space in bytes
    @objc public let availableDiskSpace: UInt64
    
    /// CPU usage as a percentage (0-100)
    @objc public let cpuUsagePercentage: Double
    
    /// System load averages for 1, 5, and 15 minutes
    @objc public let systemLoad: [Double]
    
    /// Whether this class supports secure coding
    public static var supportsSecureCoding: Bool { true }
    
    // MARK: - Initialization
    
    /// Creates a new SystemResources instance.
    ///
    /// - Parameters:
    ///   - availableMemory: Available system memory in bytes
    ///   - availableDiskSpace: Available disk space in bytes
    ///   - cpuUsagePercentage: CPU usage as a percentage (0-100)
    ///   - systemLoad: System load averages for 1, 5, and 15 minutes
    @objc public init(
        availableMemory: UInt64,
        availableDiskSpace: UInt64,
        cpuUsagePercentage: Double,
        systemLoad: [Double]
    ) {
        self.availableMemory = availableMemory
        self.availableDiskSpace = availableDiskSpace
        self.cpuUsagePercentage = min(max(cpuUsagePercentage, 0), 100)
        self.systemLoad = systemLoad.map { max($0, 0) }
        super.init()
    }
    
    // MARK: - NSSecureCoding
    
    /// Creates a SystemResources instance from an NSCoder.
    ///
    /// - Parameter coder: The NSCoder to decode from
    public required init?(coder: NSCoder) {
        guard let systemLoad = coder.decodeObject(
            of: [NSArray.self, NSNumber.self],
            forKey: "systemLoad"
        ) as? [Double] else {
            return nil
        }
        
        self.availableMemory = UInt64(coder.decodeInt64(forKey: "availableMemory"))
        self.availableDiskSpace = UInt64(coder.decodeInt64(forKey: "availableDiskSpace"))
        self.cpuUsagePercentage = coder.decodeDouble(forKey: "cpuUsagePercentage")
        self.systemLoad = systemLoad
        super.init()
    }
    
    /// Encodes the SystemResources instance to an NSCoder.
    ///
    /// - Parameter coder: The NSCoder to encode to
    public func encode(with coder: NSCoder) {
        coder.encode(Int64(availableMemory), forKey: "availableMemory")
        coder.encode(Int64(availableDiskSpace), forKey: "availableDiskSpace")
        coder.encode(cpuUsagePercentage, forKey: "cpuUsagePercentage")
        coder.encode(systemLoad as NSArray, forKey: "systemLoad")
    }
    
    // MARK: - Helpers
    
    /// Returns a string representation of available memory.
    ///
    /// - Returns: A formatted string with memory size and unit
    @objc public func formattedAvailableMemory() -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(availableMemory),
            countStyle: .memory
        )
    }
    
    /// Returns a string representation of available disk space.
    ///
    /// - Returns: A formatted string with disk space size and unit
    @objc public func formattedAvailableDiskSpace() -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(availableDiskSpace),
            countStyle: .file
        )
    }
    
    /// Returns a string representation of CPU usage.
    ///
    /// - Returns: A formatted string with CPU usage percentage
    @objc public func formattedCPUUsage() -> String {
        String(format: "%.1f%%", cpuUsagePercentage)
    }
    
    /// Returns a string representation of system load.
    ///
    /// - Returns: A formatted string with load averages
    @objc public func formattedSystemLoad() -> String {
        let loadStrings = systemLoad.map { String(format: "%.2f", $0) }
        return loadStrings.joined(separator: ", ")
    }
}

// MARK: - CustomStringConvertible

extension SystemResources: CustomStringConvertible {
    public var description: String {
        """
        SystemResources(
            memory: \(formattedAvailableMemory()),
            disk: \(formattedAvailableDiskSpace()),
            cpu: \(formattedCPUUsage()),
            load: [\(formattedSystemLoad())]
        )
        """
    }
}
