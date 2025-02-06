//
//  SandboxMonitorProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Protocol defining sandbox monitoring operations
public protocol SandboxMonitorProtocol: AnyObject {
    /// The delegate to receive sandbox monitoring events
    var delegate: SandboxMonitorDelegate? { get set }
    
    /// Start monitoring sandbox access for a URL
    /// - Parameter url: The URL to monitor
    /// - Returns: true if monitoring was successfully started
    func startMonitoring(url: URL) -> Bool
    
    /// Stop monitoring sandbox access for a URL
    /// - Parameter url: The URL to stop monitoring
    func stopMonitoring(for url: URL)
    
    /// Indicates if the monitor is currently active
    var isMonitoring: Bool { get set }
    
    /// Check if a URL is currently being monitored
    /// - Parameter url: The URL to check
    /// - Returns: true if the URL is being monitored
    func isMonitoring(url: URL) -> Bool

    /// Health check for the monitor
    var isHealthy: Bool { get }
}
