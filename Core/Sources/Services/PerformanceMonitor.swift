import Foundation
import os.log

/// Implementation of the PerformanceMonitorProtocol
public actor PerformanceMonitor: PerformanceMonitorProtocol {
    // MARK: - Properties
    
    private let logger: any LoggerProtocol
    private var operations: [UUID: MonitoredOperation]
    private var metrics: [MetricMeasurement]
    
    // MARK: - Initialisation
    
    public init(logger: any LoggerProtocol) {
        self.logger = logger
        self.operations = [:]
        self.metrics = []
    }
    
    // MARK: - PerformanceMonitorProtocol Implementation
    
    public func startOperation(_ operation: String, metadata: [String: String]?) async -> UUID {
        let operationId = UUID()
        let monitoredOperation = MonitoredOperation(
            id: operationId,
            name: operation,
            startTime: Date(),
            endTime: nil,
            status: nil,
            metadata: metadata
        )
        
        operations[operationId] = monitoredOperation
        logger.info("Started monitoring operation: \(operation)", metadata: metadata)
        
        return operationId
    }
    
    public func endOperation(_ operationId: UUID, status: OperationStatus) async {
        guard var operation = operations[operationId] else {
            logger.error("Attempted to end unknown operation: \(operationId)")
            return
        }
        
        // Create new operation with end time and status
        let endedOperation = MonitoredOperation(
            id: operation.id,
            name: operation.name,
            startTime: operation.startTime,
            endTime: Date(),
            status: status,
            metadata: operation.metadata
        )
        
        operations[operationId] = endedOperation
        
        if case .failed(let error) = status {
            logger.error("Operation failed: \(operation.name)", metadata: ["error": error.localizedDescription])
        } else {
            logger.info("Completed operation: \(operation.name)", metadata: ["duration": "\(endedOperation.duration ?? 0)ms"])
        }
    }
    
    public func recordMetric(_ name: String, value: Double, unit: MetricUnit, metadata: [String: String]?) async {
        let measurement = MetricMeasurement(
            name: name,
            value: value,
            unit: unit,
            timestamp: Date(),
            metadata: metadata
        )
        
        metrics.append(measurement)
        logger.debug("Recorded metric: \(name)=\(value)\(unit.description)", metadata: metadata)
    }
    
    public func getPerformanceReport(from startDate: Date, to endDate: Date) async -> PerformanceReport {
        let period = DateInterval(start: startDate, end: endDate)
        
        // Filter operations and metrics within the period
        let periodOperations = operations.values.filter { operation in
            period.contains(operation.startTime)
        }
        
        let periodMetrics = metrics.filter { metric in
            period.contains(metric.timestamp)
        }
        
        // Calculate statistics
        let statistics = calculateStatistics(
            operations: Array(periodOperations),
            metrics: periodMetrics
        )
        
        return PerformanceReport(
            period: period,
            operations: Array(periodOperations),
            metrics: periodMetrics,
            statistics: statistics
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateStatistics(
        operations: [MonitoredOperation],
        metrics: [MetricMeasurement]
    ) -> PerformanceStatistics {
        let completedOperations = operations.filter { $0.endTime != nil }
        let durations = completedOperations.compactMap { $0.duration }
        
        let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        let totalOps = operations.count
        let failedOps = operations.filter { 
            if case .failed = $0.status { return true }
            return false
        }.count
        
        let successRate = totalOps == 0 ? 0 : Double(totalOps - failedOps) / Double(totalOps) * 100
        
        // Calculate resource usage statistics
        let memoryMetrics = metrics.filter { 
            $0.unit == .bytes && 
            $0.name == "memory_usage" 
        }
        let cpuMetrics = metrics.filter { 
            $0.unit == .percentage && 
            $0.name == "cpu_usage" 
        }
        let speedMetrics = metrics.filter { 
            $0.unit == .bytesPerSecond && 
            $0.name == "backup_speed" 
        }
        
        let peakMemory = memoryMetrics.map { UInt64($0.value) }.max() ?? 0
        let avgCPU = cpuMetrics.isEmpty ? 0 : cpuMetrics.map { $0.value }.reduce(0, +) / Double(cpuMetrics.count)
        let peakCPU = cpuMetrics.map { $0.value }.max() ?? 0
        let avgSpeed = speedMetrics.isEmpty ? 
            0 : speedMetrics.map { $0.value }.reduce(0, +) / Double(speedMetrics.count)
        
        return PerformanceStatistics(
            averageOperationDuration: averageDuration,
            operationSuccessRate: successRate,
            peakMemoryUsage: peakMemory,
            averageCPUUsage: avgCPU,
            peakCPUUsage: peakCPU,
            averageBackupSpeed: avgSpeed,
            totalOperations: totalOps,
            failedOperations: failedOps
        )
    }
}
