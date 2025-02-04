import Foundation

/// Service for monitoring and detecting potential sandbox violations
public class SandboxMonitor {
    private let logger: LoggerProtocol
    private let fileManager: FileManager
    private let permissionManager: PermissionManager
    
    /// Queue for processing sandbox operations
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.sandboxMonitor")
    
    /// Active resource access tracking
    private var activeAccess: [URL: Date] = [:]
    
    /// Maximum duration for resource access (in seconds)
    private let maxAccessDuration: TimeInterval = 300 // 5 minutes
    
    /// Initialize sandbox monitor
    /// - Parameters:
    ///   - logger: Logger for tracking operations
    ///   - fileManager: FileManager instance to use
    ///   - permissionManager: Permission manager instance
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "SandboxMonitor"),
        fileManager: FileManager = .default,
        permissionManager: PermissionManager = PermissionManager()
    ) {
        self.logger = logger
        self.fileManager = fileManager
        self.permissionManager = permissionManager
        setupMonitoring()
    }
    
    /// Track resource access
    /// - Parameter url: The URL being accessed
    public func trackAccess(to url: URL) {
        queue.async {
            self.activeAccess[url] = Date()
            self.logger.debug(
                "Started tracking access to: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    /// Stop tracking resource access
    /// - Parameter url: The URL to stop tracking
    public func stopTracking(_ url: URL) {
        queue.async {
            self.activeAccess[url] = nil
            self.logger.debug(
                "Stopped tracking access to: \(url.path)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    /// Check if a URL is safe to access
    /// - Parameter url: The URL to check
    /// - Returns: true if the URL is safe to access
    public func isSafeToAccess(_ url: URL) async throws -> Bool {
        // Check if URL is within app container
        if url.path.starts(with: fileManager.homeDirectoryForCurrentUser.path) {
            return true
        }
        
        // Check if we have valid permission
        return try await permissionManager.hasValidPermission(for: url)
    }
    
    /// Get list of potential sandbox violations
    /// - Returns: Array of violation reports
    public func detectViolations() async -> [SandboxViolation] {
        var violations: [SandboxViolation] = []
        
        // Check for long-running access
        let longRunningAccess = queue.sync {
            activeAccess.filter { entry in
                Date().timeIntervalSince(entry.value) > maxAccessDuration
            }
        }
        
        for (url, startTime) in longRunningAccess {
            violations.append(.longRunningAccess(
                url: url,
                duration: Date().timeIntervalSince(startTime)
            ))
        }
        
        // Check for access to system directories
        let systemPaths = [
            "/System",
            "/Library",
            "/usr",
            "/bin",
            "/sbin"
        ]
        
        let activeSystemAccess = queue.sync {
            activeAccess.filter { entry in
                systemPaths.contains { entry.key.path.starts(with: $0) }
            }
        }
        
        for (url, _) in activeSystemAccess {
            violations.append(.systemDirectoryAccess(url: url))
        }
        
        return violations
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        // Start periodic violation checks
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                let violations = await self.detectViolations()
                for violation in violations {
                    self.logger.error(
                        "Sandbox violation detected: \(violation.description)",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                }
            }
        }
    }
}

/// Represents a sandbox violation
public enum SandboxViolation {
    case longRunningAccess(url: URL, duration: TimeInterval)
    case systemDirectoryAccess(url: URL)
    
    var description: String {
        switch self {
        case .longRunningAccess(let url, let duration):
            return "Long-running access (\(Int(duration))s) to: \(url.path)"
        case .systemDirectoryAccess(let url):
            return "Attempted access to system directory: \(url.path)"
        }
    }
}

/// Extension to integrate sandbox monitoring with SecurityService
extension SecurityService {
    /// Start accessing a security-scoped resource with monitoring
    /// - Parameter url: The URL to access
    /// - Returns: true if access was granted
    public func startAccessingWithMonitoring(_ url: URL) -> Bool {
        let monitor = SandboxMonitor()
        
        guard startAccessing(url) else {
            return false
        }
        
        monitor.trackAccess(to: url)
        return true
    }
    
    /// Stop accessing a security-scoped resource and update monitoring
    /// - Parameter url: The URL to stop accessing
    public func stopAccessingWithMonitoring(_ url: URL) {
        let monitor = SandboxMonitor()
        stopAccessing(url)
        monitor.stopTracking(url)
    }
}
