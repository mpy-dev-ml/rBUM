import Foundation
import AppKit

/// Service for monitoring sandbox compliance and resource access
public final class SandboxMonitor: BaseSandboxedService, SandboxMonitorProtocol, HealthCheckable {
    // MARK: - Properties
    private let monitorQueue: DispatchQueue
    private var activeResources: [URL: ResourceAccess] = [:]
    private let maxResourceAccessDuration: TimeInterval
    
    public var isHealthy: Bool {
        // Check if any resources have been accessed for too long
        !activeResources.values.contains { $0.hasExceededMaxDuration }
    }
    
    // MARK: - Types
    private struct ResourceAccess {
        let startTime: Date
        let maxDuration: TimeInterval
        var continuation: AsyncStream<SandboxAccessEvent>.Continuation?
        
        var hasExceededMaxDuration: Bool {
            Date().timeIntervalSince(startTime) > maxDuration
        }
    }
    
    // MARK: - Initialization
    public init(maxResourceAccessDuration: TimeInterval = 3600) {
        self.monitorQueue = DispatchQueue(label: "dev.mpy.rBUM.sandbox.monitor", attributes: .concurrent)
        self.maxResourceAccessDuration = maxResourceAccessDuration
        super.init(logger: LoggerFactory.createLogger(category: "SandboxMonitor"))
        setupNotifications()
    }
    
    // MARK: - SandboxMonitorProtocol Implementation
    public func monitorAccess(for url: URL) -> AsyncStream<SandboxAccessEvent> {
        AsyncStream { continuation in
            monitorQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                
                let access = ResourceAccess(
                    startTime: Date(),
                    maxDuration: self.maxResourceAccessDuration,
                    continuation: continuation
                )
                
                self.activeResources[url] = access
                
                // Initial access check
                if url.startAccessingSecurityScopedResource() {
                    continuation.yield(.accessGranted)
                } else {
                    continuation.yield(.accessDenied)
                }
            }
        }
    }
    
    public func stopMonitoring(for url: URL) {
        monitorQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let access = self.activeResources[url] {
                access.continuation?.finish()
                url.stopAccessingSecurityScopedResource()
                self.activeResources.removeValue(forKey: url)
            }
        }
    }
    
    public func isMonitoring(url: URL) -> Bool {
        monitorQueue.sync {
            activeResources.keys.contains(url)
        }
    }
    
    // MARK: - Private Methods
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate(_ notification: Notification) {
        monitorQueue.sync(flags: .barrier) {
            for (url, access) in activeResources {
                access.continuation?.finish()
                url.stopAccessingSecurityScopedResource()
            }
            activeResources.removeAll()
        }
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Sandbox Monitor Health Check") {
            let overextendedResources = monitorQueue.sync {
                activeResources.filter { $0.value.hasExceededMaxDuration }
            }
            
            if !overextendedResources.isEmpty {
                logger.warning("Found \(overextendedResources.count) resources exceeding max access duration")
                for (url, _) in overextendedResources {
                    logger.error("Resource access exceeded max duration: \(url.path)")
                }
                return false
            }
            
            logger.info("Sandbox monitor health check passed")
            return true
        }
    }
}

// MARK: - SandboxAccessEvent Definition
public enum SandboxAccessEvent {
    case accessGranted
    case accessDenied
    case accessRevoked
    case accessExpired
}

// MARK: - Sandbox Monitor Errors
public enum SandboxMonitorError: LocalizedError {
    case resourceAccessExpired(URL)
    case resourceNotTracked(URL)
    case invalidResourceState(String)
    
    public var errorDescription: String? {
        switch self {
        case .resourceAccessExpired(let url):
            return "Resource access has expired: \(url.path)"
        case .resourceNotTracked(let url):
            return "Resource is not being tracked: \(url.path)"
        case .invalidResourceState(let message):
            return "Invalid resource state: \(message)"
        }
    }
}
