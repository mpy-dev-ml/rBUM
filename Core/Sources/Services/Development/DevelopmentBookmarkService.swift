//
//  DevelopmentBookmarkService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Development mock implementation of BookmarkServiceProtocol
/// Provides simulated bookmark behaviour for development and testing
@available(macOS 13.0, *)
public final class DevelopmentBookmarkService: BookmarkServiceProtocol, HealthCheckable, @unchecked Sendable {
    // MARK: - Types
    
    /// Represents a bookmark entry with metadata
    private struct BookmarkEntry: Codable {
        let data: Data
        let createdAt: Date
        let lastAccessed: Date
        let accessCount: Int
        var isStale: Bool
        let resourceSize: UInt64
        let resourceType: String
        let permissions: [String]
        
        static func create(for url: URL) throws -> BookmarkEntry {
            let now = Date()
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .fileResourceTypeKey,
                .posixPermissionsKey
            ])
            
            return BookmarkEntry(
                data: Data("mock_bookmark_\(url.path)".utf8),
                createdAt: now,
                lastAccessed: now,
                accessCount: 0,
                isStale: false,
                resourceSize: UInt64(resourceValues.fileSize ?? 0),
                resourceType: resourceValues.fileResourceType?.rawValue ?? "unknown",
                permissions: Self.formatPermissions(resourceValues.posixPermissions)
            )
        }
        
        private static func formatPermissions(_ permissions: Int?) -> [String] {
            guard let perms = permissions else { return [] }
            var result: [String] = []
            if perms & 0o400 != 0 { result.append("read") }
            if perms & 0o200 != 0 { result.append("write") }
            if perms & 0o100 != 0 { result.append("execute") }
            return result
        }
        
        func accessed() -> BookmarkEntry {
            return BookmarkEntry(
                data: data,
                createdAt: createdAt,
                lastAccessed: Date(),
                accessCount: accessCount + 1,
                isStale: isStale,
                resourceSize: resourceSize,
                resourceType: resourceType,
                permissions: permissions
            )
        }
        
        func markStale() -> BookmarkEntry {
            return BookmarkEntry(
                data: data,
                createdAt: createdAt,
                lastAccessed: lastAccessed,
                accessCount: accessCount,
                isStale: true,
                resourceSize: resourceSize,
                resourceType: resourceType,
                permissions: permissions
            )
        }
    }
    
    // MARK: - Properties
    
    /// Logger for service operations
    private let logger: LoggerProtocol
    
    /// Queue for synchronizing access to shared resources
    private let queue = DispatchQueue(
        label: "dev.mpy.rBUM.developmentBookmark",
        attributes: .concurrent
    )
    
    /// Lock for thread-safe access to shared resources
    private let lock = NSLock()
    
    /// Storage for bookmark data and metadata
    private var bookmarks: [URL: BookmarkEntry] = [:]
    
    /// Set of URLs currently being accessed
    private var activeAccess: Set<URL> = []
    
    /// Configuration for development behavior
    private let configuration: DevelopmentConfiguration
    
    /// Metrics for bookmark operations
    private var metrics = BookmarkMetrics()
    
    /// Performance tracker
    private let performanceTracker = PerformanceTracker()
    
    /// Resource monitor
    private let resourceMonitor = ResourceMonitor()
    
    // MARK: - Initialization
    
    /// Initialize the development bookmark service
    /// - Parameters:
    ///   - logger: Logger for service operations
    ///   - configuration: Configuration for development behavior
    public init(
        logger: LoggerProtocol,
        configuration: DevelopmentConfiguration = .default
    ) {
        self.logger = logger
        self.configuration = configuration
        
        // Start monitoring if metrics collection is enabled
        if configuration.shouldCollectMetrics {
            startMetricsCollection()
        }
        
        logger.info(
            """
            Initialised DevelopmentBookmarkService with configuration:
            \(String(describing: configuration))
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - Private Methods
    
    /// Start collecting metrics at the configured interval
    private func startMetricsCollection() {
        queue.async {
            Timer.scheduledTimer(
                withTimeInterval: self.configuration.metricsCollectionInterval,
                repeats: true
            ) { [weak self] _ in
                self?.collectMetrics()
            }
        }
    }
    
    /// Collect metrics from various sources
    private func collectMetrics() {
        guard configuration.shouldCollectMetrics else { return }
        
        withThreadSafety {
            // Update performance metrics
            performanceTracker.recordMetrics()
            
            // Update resource usage
            resourceMonitor.updateResourceUsage()
            
            // Check resource limits
            if configuration.shouldSimulateResourceExhaustion {
                checkResourceLimits()
            }
            
            // Clean up stale bookmarks
            cleanupStaleBookmarks()
            
            // Log current metrics
            logMetrics()
        }
    }
    
    /// Check if resource usage exceeds configured limits
    private func checkResourceLimits() {
        let usage = resourceMonitor.currentUsage
        let limits = configuration.resourceLimits
        
        if usage.memory > limits.memory {
            logger.warning(
                "Memory usage exceeds limit: \(usage.memory) > \(limits.memory)",
                file: #file,
                function: #function,
                line: #line
            )
        }
        
        if usage.cpu > limits.cpu {
            logger.warning(
                "CPU usage exceeds limit: \(usage.cpu)% > \(limits.cpu)%",
                file: #file,
                function: #function,
                line: #line
            )
        }
        
        if usage.fileDescriptors > limits.fileDescriptors {
            logger.warning(
                "File descriptor usage exceeds limit: \(usage.fileDescriptors) > \(limits.fileDescriptors)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    /// Log current metrics
    private func logMetrics() {
        logger.info(
            """
            Current Metrics:
            - Bookmarks: \(metrics.description)
            - Performance: \(performanceTracker.description)
            - Resources: \(resourceMonitor.description)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    /// Thread-safe access to shared resources
    /// - Parameter action: Action to perform with shared resources
    /// - Returns: Result of the action
    private func withThreadSafety<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }
    
    /// Simulate failure if configured
    /// - Parameters:
    ///   - url: URL being operated on
    ///   - operation: Name of the operation
    ///   - error: Error to throw if simulation is active
    private func simulateFailureIfNeeded(
        for url: URL,
        operation: String,
        error: (URL) -> Error
    ) throws {
        guard configuration.shouldSimulateBookmarkFailures else { return }
        
        // Simulate different types of failures based on configuration
        if configuration.shouldSimulatePermissionFailures {
            throw BookmarkError.accessDenied(url)
        }
        
        if configuration.shouldSimulateTimeoutFailures {
            throw BookmarkError.operationTimeout(url)
        }
        
        logger.error(
            """
            Simulating \(operation) failure for URL: \
            \(url.path)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        metrics.recordFailure(operation: operation)
        throw error(url)
    }
    
    /// Clean up stale bookmarks
    private func cleanupStaleBookmarks() {
        let now = Date()
        let staleThreshold: TimeInterval = 3600 // 1 hour
        
        withThreadSafety {
            for (url, entry) in bookmarks {
                if now.timeIntervalSince(entry.lastAccessed) > staleThreshold {
                    bookmarks[url] = entry.markStale()
                    metrics.recordStaleBookmark()
                }
            }
        }
    }
    
    // MARK: - HealthCheckable Implementation
    
    public func checkHealth() async throws -> HealthStatus {
        let status = withThreadSafety {
            HealthStatus(
                isHealthy: true,
                details: [
                    "activeBookmarks": bookmarks.count,
                    "activeAccesses": activeAccess.count,
                    "metrics": metrics,
                    "performance": performanceTracker.currentMetrics,
                    "resources": resourceMonitor.currentUsage
                ]
            )
        }
        
        // Check resource limits
        if configuration.shouldSimulateResourceExhaustion {
            let usage = resourceMonitor.currentUsage
            let limits = configuration.resourceLimits
            
            if usage.memory > limits.memory ||
               usage.cpu > limits.cpu ||
               usage.fileDescriptors > limits.fileDescriptors {
                return HealthStatus(
                    isHealthy: false,
                    details: status.details.merging(
                        ["error": "Resource limits exceeded"],
                        uniquingKeysWith: { $1 }
                    )
                )
            }
        }
        
        return status
    }
    
    // MARK: - BookmarkServiceProtocol Implementation
    
    public func createBookmark(
        for url: URL
    ) throws -> Data {
        try simulateFailureIfNeeded(
            for: url,
            operation: "bookmark creation",
            error: BookmarkError.creationFailed
        )
        
        return try withThreadSafety {
            let entry = try BookmarkEntry.create(for: url)
            bookmarks[url] = entry
            metrics.recordCreation()
            
            logger.info(
                """
                Created bookmark for URL: \
                \(url.path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            return entry.data
        }
    }
    
    public func resolveBookmark(
        _ bookmark: Data
    ) throws -> URL {
        return try withThreadSafety {
            guard let (url, var entry) = bookmarks.first(where: { $0.value.data == bookmark }) else {
                logger.error(
                    "Failed to resolve bookmark: bookmark not found",
                    file: #file,
                    function: #function,
                    line: #line
                )
                metrics.recordFailure(operation: "resolution")
                throw BookmarkError.resolutionFailed(URL(fileURLWithPath: "/"))
            }
            
            try simulateFailureIfNeeded(
                for: url,
                operation: "bookmark resolution",
                error: BookmarkError.resolutionFailed
            )
            
            if entry.isStale {
                logger.warning(
                    """
                    Resolving stale bookmark for URL: \
                    \(url.path)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                metrics.recordStaleAccess()
            }
            
            entry = entry.accessed()
            bookmarks[url] = entry
            metrics.recordResolution()
            
            logger.info(
                """
                Resolved bookmark to URL: \
                \(url.path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            
            return try url.checkResourceIsReachable() 
                ? url 
                : URL(fileURLWithPath: "/")
        }
    }
    
    public func validateBookmark(
        _ bookmark: Data
    ) throws -> Bool {
        return try withThreadSafety {
            guard let (url, entry) = bookmarks.first(where: { $0.value.data == bookmark }) else {
                logger.warning(
                    "Bookmark validation failed: bookmark not found",
                    file: #file,
                    function: #function,
                    line: #line
                )
                metrics.recordFailure(operation: "validation")
                return false
            }
            
            try simulateFailureIfNeeded(
                for: url,
                operation: "bookmark validation",
                error: BookmarkError.invalidBookmark
            )
            
            if entry.isStale {
                logger.warning(
                    """
                    Validating stale bookmark for URL: \
                    \(url.path)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                metrics.recordStaleAccess()
                return false
            }
            
            metrics.recordValidation()
            logger.info(
                """
                Validated bookmark for URL: \
                \(url.path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            
            return true
        }
    }
    
    public func startAccessing(
        _ url: URL
    ) throws -> Bool {
        try simulateFailureIfNeeded(
            for: url,
            operation: "access start",
            error: BookmarkError.accessDenied
        )
        
        return try withThreadSafety {
            if activeAccess.contains(url) {
                logger.warning(
                    """
                    URL is already being accessed: \
                    \(url.path)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return true
            }
            
            activeAccess.insert(url)
            metrics.recordAccessStart()
            logger.info(
                """
                Started accessing URL: \
                \(url.path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            return true
        }
    }
    
    public func stopAccessing(
        _ url: URL
    ) async throws {
        if configuration.artificialDelay > 0 {
            try await Task.sleep(
                nanoseconds: UInt64(configuration.artificialDelay * 1_000_000_000)
            )
        }
        
        try withThreadSafety {
            if !activeAccess.contains(url) {
                logger.warning(
                    """
                    Attempting to stop access for URL that is not being accessed: \
                    \(url.path)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                return
            }
            
            activeAccess.remove(url)
            metrics.recordAccessStop()
            logger.info(
                """
                Stopped accessing URL: \
                \(url.path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
}

// MARK: - Bookmark Metrics

/// Tracks metrics for bookmark operations
private struct BookmarkMetrics: CustomStringConvertible {
    private(set) var creationCount: Int = 0
    private(set) var resolutionCount: Int = 0
    private(set) var validationCount: Int = 0
    private(set) var activeAccessCount: Int = 0
    private(set) var failureCount: Int = 0
    private(set) var staleBookmarkCount: Int = 0
    private(set) var staleAccessCount: Int = 0
    private(set) var operationLatencies: [String: TimeInterval] = [:]
    private(set) var errorTypes: [String: Int] = [:]
    
    var description: String {
        """
        BookmarkMetrics:
        - Creations: \(creationCount)
        - Resolutions: \(resolutionCount)
        - Validations: \(validationCount)
        - Active Accesses: \(activeAccessCount)
        - Failures: \(failureCount)
        - Stale Bookmarks: \(staleBookmarkCount)
        - Stale Accesses: \(staleAccessCount)
        - Average Latencies: \(formatLatencies())
        - Error Distribution: \(formatErrors())
        """
    }
    
    private func formatLatencies() -> String {
        operationLatencies
            .map { "\($0.key): \(String(format: "%.2f", $0.value))s" }
            .joined(separator: ", ")
    }
    
    private func formatErrors() -> String {
        errorTypes
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }
    
    mutating func recordCreation() {
        creationCount += 1
    }
    
    mutating func recordResolution() {
        resolutionCount += 1
    }
    
    mutating func recordValidation() {
        validationCount += 1
    }
    
    mutating func recordAccessStart() {
        activeAccessCount += 1
    }
    
    mutating func recordAccessStop() {
        activeAccessCount = max(0, activeAccessCount - 1)
    }
    
    mutating func recordFailure(operation: String) {
        failureCount += 1
        errorTypes[operation, default: 0] += 1
    }
    
    mutating func recordStaleBookmark() {
        staleBookmarkCount += 1
    }
    
    mutating func recordStaleAccess() {
        staleAccessCount += 1
    }
    
    mutating func recordLatency(operation: String, duration: TimeInterval) {
        let currentAvg = operationLatencies[operation, default: 0]
        let count = Double(errorTypes[operation, default: 0] + 1)
        operationLatencies[operation] = ((currentAvg * (count - 1)) + duration) / count
    }
}

// MARK: - Performance Tracking

/// Tracks performance metrics
private final class PerformanceTracker: CustomStringConvertible {
    private var metrics: [String: Double] = [:]
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.performanceTracker")
    
    var currentMetrics: [String: Double] {
        queue.sync { metrics }
    }
    
    var description: String {
        queue.sync {
            metrics
                .map { "\($0.key): \(String(format: "%.2f", $0.value))" }
                .joined(separator: ", ")
        }
    }
    
    func recordMetrics() {
        queue.async {
            self.metrics["cpuUsage"] = self.measureCPUUsage()
            self.metrics["memoryUsage"] = self.measureMemoryUsage()
            self.metrics["diskIO"] = self.measureDiskIO()
        }
    }
    
    private func measureCPUUsage() -> Double {
        // Simulated CPU measurement
        return Double.random(in: 0...100)
    }
    
    private func measureMemoryUsage() -> Double {
        // Simulated memory measurement
        return Double.random(in: 0...1024)
    }
    
    private func measureDiskIO() -> Double {
        // Simulated disk I/O measurement
        return Double.random(in: 0...100)
    }
}

// MARK: - Resource Monitoring

/// Monitors system resource usage
private final class ResourceMonitor: CustomStringConvertible {
    private var usage: ResourceUsage = .zero
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.resourceMonitor")
    
    struct ResourceUsage {
        var cpu: Double
        var memory: UInt64
        var disk: UInt64
        var fileDescriptors: Int
        var networkBandwidth: UInt64
        
        static let zero = ResourceUsage(
            cpu: 0,
            memory: 0,
            disk: 0,
            fileDescriptors: 0,
            networkBandwidth: 0
        )
    }
    
    var currentUsage: ResourceUsage {
        queue.sync { usage }
    }
    
    var description: String {
        let usage = currentUsage
        return """
        ResourceUsage:
        - CPU: \(String(format: "%.1f", usage.cpu))%
        - Memory: \(ByteCountFormatter.string(fromByteCount: Int64(usage.memory), countStyle: .binary))
        - Disk: \(ByteCountFormatter.string(fromByteCount: Int64(usage.disk), countStyle: .binary))
        - File Descriptors: \(usage.fileDescriptors)
        - Network Bandwidth: \(ByteCountFormatter.string(fromByteCount: Int64(usage.networkBandwidth), countStyle: .binary))/s
        """
    }
    
    func updateResourceUsage() {
        queue.async {
            // Simulate resource usage measurements
            self.usage = ResourceUsage(
                cpu: Double.random(in: 0...100),
                memory: UInt64.random(in: 0...(1024 * 1024 * 1024)),
                disk: UInt64.random(in: 0...(10 * 1024 * 1024 * 1024)),
                fileDescriptors: Int.random(in: 0...1000),
                networkBandwidth: UInt64.random(in: 0...(100 * 1024 * 1024))
            )
        }
    }
}
