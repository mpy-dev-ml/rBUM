import Foundation

/// Protocol defining sandbox monitoring operations
public protocol SandboxMonitorProtocol {
    /// Monitor changes to sandbox access for a URL
    /// - Parameter url: The URL to monitor
    /// - Returns: An async sequence of sandbox access events
    func monitorAccess(for url: URL) -> AsyncStream<SandboxAccessEvent>
    
    /// Stop monitoring sandbox access for a URL
    /// - Parameter url: The URL to stop monitoring
    func stopMonitoring(for url: URL)
    
    /// Check if a URL is currently being monitored
    /// - Parameter url: The URL to check
    /// - Returns: true if the URL is being monitored
    func isMonitoring(url: URL) -> Bool
}

/// Events that can occur during sandbox access monitoring
public enum SandboxAccessEvent {
    /// Access to the resource was granted
    case accessGranted
    /// Access to the resource was revoked
    case accessRevoked
    /// Access to the resource expired
    case accessExpired
    /// Access to the resource needs renewal
    case accessNeedsRenewal
}
