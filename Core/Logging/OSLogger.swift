    import Foundation
import os.log

#if os(macOS)
/// OSLogger implementation of LoggerProtocol using os.Logger
public final class OSLogger: LoggerProtocol, HealthCheckable {
    // MARK: - Properties
    private let logger: os.Logger
    private let subsystem: String
    private let category: String
    
    public var isHealthy: Bool {
        true // Logger is typically always healthy unless system-level issues
    }
    
    // MARK: - Initialization
    public init(subsystem: String = "dev.mpy.rBUM", category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - LoggerProtocol Implementation
    public func debug(_ message: String, file: String, function: String, line: Int) {
        logger.debug("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func info(_ message: String, file: String, function: String, line: Int) {
        logger.info("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func warning(_ message: String, file: String, function: String, line: Int) {
        logger.warning("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    public func error(_ message: String, file: String, function: String, line: Int) {
        logger.error("\(message, privacy: .public) [\(file):\(line) \(function)]")
    }
    
    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        // Log a test message to verify logger is working
        logger.debug("Health check: Logger is operational")
        return isHealthy
    }
}

// MARK: - OSLogger Factory

extension OSLogger {
    /// Create a new OSLogger instance with default subsystem
    /// - Parameter category: Category for the logger
    /// - Returns: A new OSLogger instance
    public static func create(category: String) -> OSLogger {
        OSLogger(category: category)
    }
    
    /// Create a new OSLogger instance with custom subsystem
    /// - Parameters:
    ///   - subsystem: Subsystem identifier
    ///   - category: Category for the logger
    /// - Returns: A new OSLogger instance
    public static func create(subsystem: String, category: String) -> OSLogger {
        OSLogger(subsystem: subsystem, category: category)
    }
}

/// Default logger implementation for the current platform
public typealias DefaultLogger = OSLogger
#endif
