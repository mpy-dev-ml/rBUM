import Foundation
import os.log

/// A struct responsible for recording and logging security-related operations in the system.
///
/// The `SecurityOperationRecorder` provides a centralised way to record security operations,
/// ensuring consistent logging and tracking of all security-related activities. This is
/// particularly important for:
/// - Debugging security issues
/// - Auditing security operations
/// - Monitoring system behaviour
/// - Identifying potential security vulnerabilities
///
/// Example usage:
/// ```swift
/// let recorder = SecurityOperationRecorder(logger: logger)
/// recorder.recordOperation(
///     url: fileURL,
///     type: .access,
///     status: .success
/// )
/// ```
@available(macOS 13.0, *)
public struct SecurityOperationRecorder {
    private let logger: Logger

    /// Initializes a new SecurityOperationRecorder with the specified logger.
    ///
    /// - Parameter logger: The logger instance to use for recording operations
    public init(logger: Logger) {
        self.logger = logger
    }

    /// Records a security operation with the specified parameters.
    ///
    /// This method creates a new `SecurityOperation` instance and logs it using the configured
    /// logger. It captures all relevant information about the operation including the URL,
    /// operation type, status, and any error that occurred.
    ///
    /// - Parameters:
    ///   - url: The URL associated with the security operation
    ///   - type: The type of security operation being performed
    ///   - status: The status of the operation (success or failure)
    ///   - error: An optional error message if the operation failed
    func recordOperation(
        url: URL,
        type: SecurityOperationType,
        status: SecurityOperationStatus,
        error: String? = nil
    ) {
        let operation = SecurityOperation(
            url: url,
            operationType: type,
            timestamp: Date(),
            status: status,
            error: error
        )
        logger.info(
            """
            Recorded operation: \
            \(operation.operationType.rawValue) \
            to URL: \(operation.url.path) \
            with status: \(operation.status.rawValue)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }
}
