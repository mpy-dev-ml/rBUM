import Foundation
import os.log

/// Service for monitoring and diagnosing sandbox-related issues
public class SandboxDiagnostics {
    private let logger: LoggerProtocol
    private let subsystem = "dev.mpy.rBUM"
    
    public init(logger: LoggerProtocol = LoggerFactory.createLogger(category: "SandboxDiagnostics")) {
        self.logger = logger
        setupSignposts()
    }
    
    // MARK: - Signpost Logging
    
    private func setupSignposts() {
        if #available(macOS 10.14, *) {
            let log = OSLog(subsystem: subsystem, category: "Sandbox")
            os_signpost_interval_begin(log, "FileAccess")
        }
    }
    
    // MARK: - Diagnostic Methods
    
    /// Monitor file system access
    public func monitorFileAccess(url: URL, operation: String) {
        logger.debug("File access attempt: \(url.path, privacy: .private) - Operation: \(operation, privacy: .public)")
        
        // Check if path is within sandbox
        if !url.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) &&
           !url.path.hasPrefix("/private/tmp") {
            logger.error("Potential sandbox violation: Accessing path outside sandbox", privacy: .public)
            logViolation(type: .fileAccess, path: url.path)
        }
    }
    
    /// Monitor network access
    public func monitorNetworkAccess(host: String, port: Int) {
        logger.debug("Network access attempt: \(host, privacy: .private):\(port, privacy: .public)")
        
        // Check for restricted ports
        if port < 1024 && port != 80 && port != 443 {
            logger.error("Potential sandbox violation: Accessing restricted port", privacy: .public)
            logViolation(type: .network, path: "\(host):\(port)")
        }
    }
    
    /// Monitor IPC operations
    public func monitorIPCAccess(service: String) {
        logger.debug("IPC access attempt: \(service, privacy: .public)")
        
        // Check for allowed XPC services
        if !service.hasPrefix("dev.mpy.rBUM") {
            logger.error("Potential sandbox violation: Accessing unauthorized XPC service", privacy: .public)
            logViolation(type: .ipc, path: service)
        }
    }
    
    // MARK: - Violation Handling
    
    private enum ViolationType {
        case fileAccess
        case network
        case ipc
        
        var description: String {
            switch self {
            case .fileAccess: return "File Access Violation"
            case .network: return "Network Access Violation"
            case .ipc: return "IPC Access Violation"
            }
        }
    }
    
    private func logViolation(type: ViolationType, path: String) {
        // Log to system log
        if #available(macOS 10.14, *) {
            let log = OSLog(subsystem: subsystem, category: "SandboxViolation")
            os_log(.fault, log: log, "Sandbox Violation - Type: %{public}@ Path: %{private}@",
                   type.description, path)
        }
        
        // Store violation for analysis
        storeViolation(type: type, path: path)
    }
    
    private func storeViolation(type: ViolationType, path: String) {
        let violation = [
            "type": type.description,
            "path": path,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "process": ProcessInfo.processInfo.processName
        ]
        
        // Store in app's container
        if let violationsURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("SandboxViolations.json") {
            
            var violations: [[String: String]] = []
            if let data = try? Data(contentsOf: violationsURL),
               let existing = try? JSONDecoder().decode([[String: String]].self, from: data) {
                violations = existing
            }
            
            violations.append(violation)
            
            // Keep only last 100 violations
            if violations.count > 100 {
                violations.removeFirst(violations.count - 100)
            }
            
            if let data = try? JSONEncoder().encode(violations) {
                try? data.write(to: violationsURL)
            }
        }
    }
    
    /// Get recent sandbox violations
    public func getRecentViolations() -> [[String: String]] {
        if let violationsURL = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ).appendingPathComponent("SandboxViolations.json"),
           let data = try? Data(contentsOf: violationsURL),
           let violations = try? JSONDecoder().decode([[String: String]].self, from: data) {
            return violations
        }
        return []
    }
}
