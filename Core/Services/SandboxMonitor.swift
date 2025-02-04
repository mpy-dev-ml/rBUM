import Foundation

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
        
        var hasExceededMaxDuration: Bool {
            Date().timeIntervalSince(startTime) > maxDuration
        }
    }
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        maxResourceAccessDuration: TimeInterval = 300 // 5 minutes default
    ) {
        self.maxResourceAccessDuration = maxResourceAccessDuration
        self.monitorQueue = DispatchQueue(label: "dev.mpy.rBUM.sandboxMonitor", attributes: .concurrent)
        super.init(logger: logger, securityService: securityService)
        
        // Start periodic health check
        startPeriodicHealthCheck()
    }
    
    // MARK: - SandboxMonitorProtocol Implementation
    public func trackResourceAccess(to url: URL) {
        monitorQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.activeResources[url] = ResourceAccess(
                startTime: Date(),
                maxDuration: self.maxResourceAccessDuration
            )
            self.logger.debug("Started tracking resource access to \(url.path)")
        }
    }
    
    public func stopTrackingResource(_ url: URL) {
        monitorQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.activeResources.removeValue(forKey: url)
            self.logger.debug("Stopped tracking resource access to \(url.path)")
        }
    }
    
    public func checkResourceAccess(_ url: URL) -> Bool {
        monitorQueue.sync {
            guard let access = activeResources[url] else {
                return false
            }
            return !access.hasExceededMaxDuration
        }
    }
    
    public func listActiveResources() -> [URL] {
        monitorQueue.sync {
            Array(activeResources.keys)
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
    
    // MARK: - Private Helpers
    private func startPeriodicHealthCheck() {
        Task {
            while !Task.isCancelled {
                if !await performHealthCheck() {
                    // Clean up overextended resources
                    monitorQueue.async(flags: .barrier) { [weak self] in
                        guard let self = self else { return }
                        let overextended = self.activeResources.filter { $0.value.hasExceededMaxDuration }
                        for (url, _) in overextended {
                            self.activeResources.removeValue(forKey: url)
                            self.logger.warning("Automatically removed overextended resource access: \(url.path)")
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000)) // Check every minute
            }
        }
    }
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
