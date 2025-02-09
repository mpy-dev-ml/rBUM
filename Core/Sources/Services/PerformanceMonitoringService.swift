import Combine
import Foundation

/// Service responsible for monitoring and alerting on performance metrics
public actor PerformanceMonitoringService {
    // MARK: - Properties
    
    private let monitor: PerformanceMonitorProtocol
    private let logger: any LoggerProtocol
    private let thresholds: PerformanceThresholds
    private var alertPublisher: PassthroughSubject<PerformanceAlert, Never>
    private var activeAlerts: Set<PerformanceAlert.AlertType>
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Initialisation
    
    /// Initialises a new PerformanceMonitoringService instance
    /// - Parameters:
    ///   - monitor: The performance monitor implementation to use
    ///   - logger: The logger implementation to use
    ///   - thresholds: Performance thresholds for triggering alerts (default: PerformanceThresholds())
    public init(
        monitor: PerformanceMonitorProtocol,
        logger: any LoggerProtocol,
        thresholds: PerformanceThresholds = PerformanceThresholds()
    ) {
        self.monitor = monitor
        self.logger = logger
        self.thresholds = thresholds
        self.alertPublisher = PassthroughSubject<PerformanceAlert, Never>()
        self.activeAlerts = []
    }
    
    // MARK: - Public Methods
    
    /// Starts monitoring performance metrics and emitting alerts
    public func startMonitoring() {
        monitoringTask = Task { [weak self] in
            await self?.monitorPerformance()
        }
    }
    
    /// Stops monitoring performance metrics and emitting alerts
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    /// Returns a publisher for receiving performance alerts
    public func alertsPublisher() -> AnyPublisher<PerformanceAlert, Never> {
        alertPublisher.eraseToAnyPublisher()
    }
    
    /// Monitors a backup operation and emits alerts for performance issues
    /// - Parameters:
    ///   - repositoryId: The ID of the repository being backed up
    ///   - sourceSize: The size of the source data being backed up
    /// - Returns: The ID of the backup operation
    public func monitorBackupOperation(
        repositoryId: String,
        sourceSize: UInt64
    ) async -> UUID {
        let operationId = await monitor.startOperation(
            "backup",
            metadata: ["repository": repositoryId]
        )
        
        // Start monitoring backup speed
        Task {
            var lastBytes: UInt64 = 0
            var lastTime = Date()
            
            while !Task.isCancelled {
                // Simulate getting current backup progress
                // In real implementation, this would come from the backup service
                let currentBytes: UInt64 = 0 // Get from backup service
                let currentTime = Date()
                
                let bytesPerSecond = Double(currentBytes - lastBytes) /
                    currentTime.timeIntervalSince(lastTime)
                
                await monitor.recordMetric(
                    "backup_speed",
                    value: bytesPerSecond,
                    unit: .bytesPerSecond,
                    metadata: ["repository": repositoryId]
                )
                
                if bytesPerSecond < thresholds.minBackupSpeed {
                    await checkAndEmitAlert(
                        type: .lowBackupSpeed,
                        message: "Backup speed is below threshold",
                        context: ["repository": repositoryId]
                    )
                }
                
                lastBytes = currentBytes
                lastTime = currentTime
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        return operationId
    }
    
    // MARK: - Private Methods
    
    private func monitorPerformance() async {
        while !Task.isCancelled {
            // Monitor system resources
            let resourceUsage = await getCurrentResourceUsage()
            
            // Record metrics
            await monitor.recordMetric(
                "memory_usage",
                value: Double(resourceUsage.memory),
                unit: .bytes,
                metadata: nil
            )
            
            await monitor.recordMetric(
                "cpu_usage",
                value: resourceUsage.cpu,
                unit: .percentage,
                metadata: nil
            )
            
            // Check thresholds
            if resourceUsage.memory > thresholds.maxMemoryUsage {
                await checkAndEmitAlert(
                    type: .highMemoryUsage,
                    message: "Memory usage exceeds threshold",
                    context: ["usage": "\(resourceUsage.memory)"]
                )
            }
            
            if resourceUsage.cpu > thresholds.maxCPUUsage {
                await checkAndEmitAlert(
                    type: .highCPUUsage,
                    message: "CPU usage exceeds threshold",
                    context: ["usage": "\(resourceUsage.cpu)"]
                )
            }
            
            // Check operation success rate
            let now = Date()
            let report = await monitor.getPerformanceReport(
                from: now.addingTimeInterval(-3600), // Last hour
                to: now
            )
            
            if report.statistics.operationSuccessRate < thresholds.minSuccessRate {
                await checkAndEmitAlert(
                    type: .lowSuccessRate,
                    message: "Operation success rate below threshold",
                    context: ["rate": "\(report.statistics.operationSuccessRate)"]
                )
            }
            
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
    }
    
    private func getCurrentResourceUsage() async -> ResourceUsage {
        // In real implementation, this would use system APIs
        // For now, return dummy values
        return ResourceUsage(
            memory: 512 * 1024 * 1024,
            cpu: 30.0,
            fileDescriptors: 50
        )
    }
    
    private func checkAndEmitAlert(
        type: PerformanceAlert.AlertType,
        message: String,
        context: [String: String],
        severity: PerformanceAlert.AlertSeverity = .warning
    ) async {
        guard !activeAlerts.contains(type) else { return }
        
        let alert = PerformanceAlert(
            id: UUID(),
            timestamp: Date(),
            severity: severity,
            type: type,
            message: message,
            context: context
        )
        
        activeAlerts.insert(type)
        alertPublisher.send(alert)
        
        // Clear alert after delay
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
            activeAlerts.remove(type)
        }
    }
}
