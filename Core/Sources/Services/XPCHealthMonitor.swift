import Foundation

/// Monitors the health of XPC services
@available(macOS 13.0, *)
public actor XPCHealthMonitor {
    // MARK: - Properties
    
    /// Current health status
    private(set) var currentStatus: XPCHealthStatus
    
    /// Logger instance
    private let logger: LoggerProtocol
    
    /// Connection manager
    private let connectionManager: XPCConnectionManager
    
    /// Health check timer
    private var healthCheckTimer: Timer?
    
    /// Health check interval in seconds
    private let healthCheckInterval: TimeInterval
    
    /// Number of consecutive successful health checks
    private var successfulChecks: Int = 0
    
    /// Number of consecutive failed health checks
    private var failedChecks: Int = 0
    
    /// Last recorded response time
    private var lastResponseTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    /// Initialize the health monitor
    /// - Parameters:
    ///   - connectionManager: XPC connection manager
    ///   - logger: Logger instance
    ///   - interval: Health check interval in seconds
    public init(
        connectionManager: XPCConnectionManager,
        logger: LoggerProtocol,
        interval: TimeInterval = 30.0
    ) {
        self.connectionManager = connectionManager
        self.logger = logger
        self.healthCheckInterval = interval
        self.currentStatus = XPCHealthStatus(
            state: .unknown("Initial state"),
            lastChecked: Date(),
            responseTime: 0,
            successfulChecks: 0,
            failedChecks: 0,
            resources: SystemResources(
                cpuUsage: 0,
                memoryUsage: 0,
                availableDiskSpace: 0,
                activeFileHandles: 0,
                activeConnections: 0
            )
        )
    }
    
    // MARK: - Health Monitoring
    
    /// Start health monitoring
    public func startMonitoring() {
        stopMonitoring()
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
        
        // Perform initial health check
        Task {
            await performHealthCheck()
        }
    }
    
    /// Stop health monitoring
    public func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    /// Perform a health check
    public func performHealthCheck() async {
        let startTime = Date()
        
        do {
            let connection = try await connectionManager.establishConnection()
            
            guard let remote = connection.remoteObjectProxyWithErrorHandler({ [weak self] error in
                Task { await self?.handleHealthCheckError(error) }
            }) as? ResticXPCProtocol else {
                throw ResticXPCError.invalidRemoteObject
            }
            
            // Check connection health
            let isHealthy = try await remote.ping()
            
            // Get system resources
            let resources = try await remote.checkResources()
            
            // Calculate response time
            let responseTime = Date().timeIntervalSince(startTime)
            
            // Update metrics
            if isHealthy && resources.isWithinLimits {
                successfulChecks += 1
                failedChecks = 0
                updateStatus(.healthy, resources: resources, responseTime: responseTime)
            } else {
                handleDegradedService(resources: resources, responseTime: responseTime)
            }
        } catch {
            handleHealthCheckError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleDegradedService(resources: SystemResources, responseTime: TimeInterval) {
        successfulChecks = 0
        failedChecks += 1
        
        let reason = resources.isWithinLimits
            ? "Degraded service performance (response time: \(String(format: "%.2f", responseTime))s)"
            : "System resources exceeded limits"
        
        updateStatus(.degraded(reason), resources: resources, responseTime: responseTime)
    }
    
    private func handleHealthCheckError(_ error: Error) {
        successfulChecks = 0
        failedChecks += 1
        
        updateStatus(
            .unhealthy(error.localizedDescription),
            resources: SystemResources(
                cpuUsage: 0,
                memoryUsage: 0,
                availableDiskSpace: 0,
                activeFileHandles: 0,
                activeConnections: 0
            ),
            responseTime: 0
        )
    }
    
    private func updateStatus(_ state: XPCHealthStatus.State, resources: SystemResources, responseTime: TimeInterval) {
        let oldStatus = currentStatus
        currentStatus = XPCHealthStatus(
            state: state,
            lastChecked: Date(),
            responseTime: responseTime,
            successfulChecks: successfulChecks,
            failedChecks: failedChecks,
            resources: resources
        )
        
        // Log status change if state changed
        if oldStatus.state != currentStatus.state {
            logger.info("Health status changed: \(oldStatus.state) -> \(currentStatus.state)", privacy: .public)
        }
        
        // Post notification
        NotificationCenter.default.post(
            name: .xpcHealthStatusChanged,
            object: nil,
            userInfo: [
                "oldStatus": oldStatus,
                "newStatus": currentStatus
            ]
        )
        
        // Log warning if attention required
        if currentStatus.requiresAttention {
            logger.warning("XPC service requires attention: \(state)", privacy: .public)
        }
    }
}
