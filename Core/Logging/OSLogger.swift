    import Foundation
import os.log

#if os(macOS)
/// Logger implementation using os.log with sandbox compliance and privacy controls
public final class OSLogger: LoggerProtocol {
    private let logger: os.Logger
    private let queue: DispatchQueue
    
    /// The subsystem identifier for this logger
    public let subsystem: String
    
    /// The category for this logger
    public let category: String
    
    /// Initialize a new logger
    /// - Parameters:
    ///   - subsystem: The subsystem for grouping related logging (e.g., "dev.mpy.rBUM")
    ///   - category: The category within the subsystem (e.g., "SecurityService")
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.queue = DispatchQueue(label: "dev.mpy.rBUM.logger.\(category)", qos: .utility)
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        queue.async {
            let filename = self.sanitizeSourcePath(file)
            self.logger.debug("[\(filename, privacy: .public):\(line, privacy: .public)] \(message, privacy: .private)")
        }
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        queue.async {
            let filename = self.sanitizeSourcePath(file)
            self.logger.info("[\(filename, privacy: .public):\(line, privacy: .public)] \(message, privacy: .auto)")
        }
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        queue.async {
            let filename = self.sanitizeSourcePath(file)
            self.logger.error("[\(filename, privacy: .public):\(line, privacy: .public)] \(message, privacy: .private)")
        }
    }
    
    // MARK: - Sandbox-Aware Helpers
    
    /// Sanitize file paths to avoid leaking sandbox paths
    private func sanitizeSourcePath(_ path: String) -> String {
        guard let lastComponent = path.split(separator: "/").last else {
            return path
        }
        return String(lastComponent)
    }
}

/// Default logger implementation for the current platform
public typealias DefaultLogger = OSLogger
#endif
