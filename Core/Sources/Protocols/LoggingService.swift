import Foundation
import os.log

/// Protocol for services that require logging capabilities.
/// This protocol provides a standardised way to handle logging across the application,
/// ensuring consistent log formatting and level-appropriate messaging.
public protocol LoggingService {
    /// The logger instance used by this service.
    /// This property should be configured during service initialization
    /// and remain constant throughout the service's lifecycle.
    var logger: LoggerProtocol { get }
}

// MARK: - Log Level

/// Represents the available logging levels with their descriptions
public enum LogLevel {
    /// Debug level for detailed information during development
    case debug
    /// Info level for general operational information
    case info
    /// Warning level for potentially harmful situations
    case warning
    /// Error level for errors that might still allow the application to continue running
    case error
    /// Fault level for severe errors that may prevent proper functioning
    case fault

    /// Convert to OSLogType
    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .warning: .default
        case .error: .error
        case .fault: .fault
        }
    }

    /// String representation for logging
    var description: String {
        switch self {
        case .debug: "DEBUG"
        case .info: "INFO"
        case .warning: "WARNING"
        case .error: "ERROR"
        case .fault: "FAULT"
        }
    }
}

// MARK: - Performance Metrics

/// Structure to hold performance metrics for logging
public struct PerformanceMetrics {
    /// Start time of the operation
    let startTime: Date

    /// End time of the operation
    let endTime: Date

    /// Duration of the operation in seconds
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Memory usage in bytes
    var memoryUsage: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    /// Format metrics as a string
    var description: String {
        """
        Duration: \(String(format: "%.3f", duration))s, \
        Memory: \(ByteCountFormatter.string(
            fromByteCount: Int64(memoryUsage),
            countStyle: .file
        ))
        """
    }
}

public extension LoggingService {
    /// Log a message with performance metrics
    /// - Parameters:
    ///   - level: Log level for the message
    ///   - message: The message to log
    ///   - metrics: Optional performance metrics
    ///   - file: Source file
    ///   - function: Function name
    ///   - line: Line number
    private func log(
        level: LogLevel,
        message: String,
        metrics: PerformanceMetrics? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let metricsString = metrics.map { " [\($0.description)]" } ?? ""
        let formattedMessage = "[\(level.description)] \(message)\(metricsString)"

        switch level {
        case .debug:
            logger.debug(formattedMessage, file: file, function: function, line: line)
        case .info:
            logger.info(formattedMessage, file: file, function: function, line: line)
        case .warning:
            logger.warning(formattedMessage, file: file, function: function, line: line)
        case .error:
            logger.error(formattedMessage, file: file, function: function, line: line)
        case .fault:
            logger.fault(formattedMessage, file: file, function: function, line: line)
        }
    }

    /// Logs an operation's execution time and any errors that occur during its execution.
    /// This method wraps an operation with timing information and appropriate error handling,
    /// ensuring consistent logging across all service operations.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being performed
    ///   - level: The logging level to use (default: .debug)
    ///   - operation: The operation to perform and measure
    ///
    /// - Returns: The result of the operation
    /// - Throws: Rethrows any error thrown by the operation
    func logOperation<T>(
        _ name: String,
        level: LogLevel = .debug,
        perform operation: () throws -> T
    ) rethrows -> T {
        let startTime = Date()

        do {
            let result = try operation()
            let metrics = PerformanceMetrics(
                startTime: startTime,
                endTime: Date()
            )
            log(
                level: level,
                message: "\(name) completed successfully",
                metrics: metrics
            )
            return result
        } catch {
            let metrics = PerformanceMetrics(
                startTime: startTime,
                endTime: Date()
            )
            log(
                level: .error,
                message: "\(name) failed with error: \(error.localizedDescription)",
                metrics: metrics
            )
            throw error
        }
    }

    /// Logs an asynchronous operation's execution time and any errors that occur during its execution.
    /// This method wraps an asynchronous operation with timing information and appropriate error handling,
    /// ensuring consistent logging across all service operations.
    ///
    /// - Parameters:
    ///   - name: The name of the operation being performed
    ///   - level: The logging level to use (default: .debug)
    ///   - operation: The asynchronous operation to perform and measure
    ///
    /// - Returns: The result of the operation
    /// - Throws: Rethrows any error thrown by the operation
    func logAsyncOperation<T>(
        _ name: String,
        level: LogLevel = .debug,
        perform operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()

        do {
            let result = try await operation()
            let metrics = PerformanceMetrics(
                startTime: startTime,
                endTime: Date()
            )
            log(
                level: level,
                message: "\(name) completed successfully",
                metrics: metrics
            )
            return result
        } catch {
            let metrics = PerformanceMetrics(
                startTime: startTime,
                endTime: Date()
            )
            log(
                level: .error,
                message: "\(name) failed with error: \(error.localizedDescription)",
                metrics: metrics
            )
            throw error
        }
    }
}
