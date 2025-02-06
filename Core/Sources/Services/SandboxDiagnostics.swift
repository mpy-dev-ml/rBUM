//
//  SandboxDiagnostics.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import os.log
import os.signpost

/// Service for monitoring and diagnosing sandbox-related issues
public class SandboxDiagnostics {
    private let logger: LoggerProtocol
    private let subsystem = "dev.mpy.rBUM"
    private let signpostLog: OSLog
    
    /// Initialize sandbox diagnostics
    /// - Parameter logger: Logger for tracking operations
    public init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "SandboxDiagnostics")
    ) {
        self.logger = logger
        self.signpostLog = OSLog(subsystem: subsystem, category: "Sandbox")
        setupSignposts()
    }
    
    // MARK: - Signpost Logging
    
    private func setupSignposts() {
        if #available(macOS 10.14, *) {
            let signpostID = OSSignpostID(log: signpostLog)
            os_signpost(.begin, log: signpostLog, name: "FileAccess", signpostID: signpostID)
        }
    }
    
    // MARK: - Diagnostic Methods
    
    /// Monitor file system access
    public func monitorFileAccess(url: URL, operation: String) {
        logger.debug(
            "File access attempt: \(url.path) - Operation: \(operation)",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Check if path is within sandbox
        if !url.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path) &&
           !url.path.hasPrefix("/private/tmp") {
            logger.error(
                "Potential sandbox violation: Accessing path outside sandbox",
                file: #file,
                function: #function,
                line: #line
            )
            logViolation(type: .fileAccess, path: url.path)
        }
    }
    
    /// Monitor network access
    public func monitorNetworkAccess(host: String, port: Int) {
        logger.debug(
            "Network access attempt: \(host):\(port)",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Check for restricted ports
        if port < 1024 && port != 80 && port != 443 {
            logger.error(
                "Potential sandbox violation: Accessing restricted port",
                file: #file,
                function: #function,
                line: #line
            )
            logViolation(type: .network, path: "\(host):\(port)")
        }
    }
    
    /// Monitor IPC operations
    public func monitorIPCAccess(service: String) {
        logger.debug(
            "IPC access attempt: \(service)",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Check for allowed XPC services
        if !service.hasPrefix("dev.mpy.rBUM") {
            logger.error(
                "Potential sandbox violation: Accessing unauthorized XPC service",
                file: #file,
                function: #function,
                line: #line
            )
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
            let violationLog = OSLog(subsystem: subsystem, category: "SandboxViolation")
            os_log(
                .fault,
                log: violationLog,
                "Sandbox Violation - Type: %{public}s Path: %{private}s",
                type.description,
                path
            )
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
        
        do {
            // Get violations file URL
            let violationsURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("SandboxViolations.json")
            
            // Read existing violations or create new array
            var violations: [[String: String]] = []
            if let data = try? Data(contentsOf: violationsURL),
               let existingViolations = try? JSONDecoder().decode([[String: String]].self, from: data) {
                violations = existingViolations
            }
            
            // Add new violation and write back
            violations.append(violation)
            let data = try JSONEncoder().encode(violations)
            try data.write(to: violationsURL, options: .atomicWrite)
            
            logger.info(
                "Stored sandbox violation record",
                file: #file,
                function: #function,
                line: #line
            )
            
        } catch {
            logger.error(
                "Failed to store violation record: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
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
    
    // MARK: - Cleanup
    
    deinit {
        if #available(macOS 10.14, *) {
            let signpostID = OSSignpostID(log: signpostLog)
            os_signpost(.end, log: signpostLog, name: "FileAccess", signpostID: signpostID)
        }
    }
}
