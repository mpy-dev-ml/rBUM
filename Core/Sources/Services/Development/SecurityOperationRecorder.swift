import Foundation
import os.log

/// Represents a security operation with metadata
public struct SecurityOperation: Hashable {
    public let url: URL
    public let type: SecurityOperationType
    public let timestamp: Date
    public let status: SecurityOperationStatus
    public let error: String?

    public init(
        url: URL,
        type: SecurityOperationType,
        timestamp: Date = Date(),
        status: SecurityOperationStatus,
        error: String? = nil
    ) {
        self.url = url
        self.type = type
        self.timestamp = timestamp
        self.status = status
        self.error = error
    }

    public static func == (lhs: SecurityOperation, rhs: SecurityOperation) -> Bool {
        lhs.url == rhs.url &&
            lhs.type == rhs.type &&
            lhs.timestamp == rhs.timestamp
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(type)
        hasher.combine(timestamp)
    }
}

/// Represents the type of a security operation
public enum SecurityOperationType: String {
    case access
    case permission
    case bookmark
    case xpc
}

/// Represents the status of a security operation
public enum SecurityOperationStatus: String {
    case success
    case failure
    case pending
}

/// Records and manages security operations for development and testing
@available(macOS 13.0, *)
public final class SecurityOperationRecorder {
    private let logger: Logger
    private let queue = DispatchQueue(label: "dev.mpy.rbum.security.operations")
    private var operations: Set<SecurityOperation> = []

    public init(logger: Logger) {
        self.logger = logger
    }

    /// Records a new security operation with the provided details
    /// - Parameters:
    ///   - url: The URL of the security operation
    ///   - type: The type of the security operation
    ///   - status: The status of the operation
    ///   - error: Additional details about the operation
    public func recordOperation(
        url: URL,
        type: SecurityOperationType,
        status: SecurityOperationStatus,
        error: String? = nil
    ) {
        queue.sync {
            let operation = SecurityOperation(
                url: url,
                type: type,
                timestamp: Date(),
                status: status,
                error: error
            )
            operations.insert(operation)

            logger.info("""
            Recording security operation:
            Type: \(type.rawValue)
            URL: \(url.path)
            Status: \(status.rawValue)
            \(error.map { "Error: \($0)" } ?? "")
            """)
        }
    }

    /// Retrieves all recorded operations for a specific URL
    /// - Parameter url: The URL to get operations for
    /// - Returns: An array of security operations sorted by timestamp
    public func getOperations(for url: URL) -> [SecurityOperation] {
        queue.sync {
            operations.filter { $0.url == url }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }

    /// Clears all recorded operations from memory
    /// This is useful for testing and when needing to reset the recorder's state
    public func clearOperations() {
        queue.sync {
            operations.removeAll()
        }
    }

    /// Retrieves all recorded operations
    /// - Returns: An array of all security operations sorted by timestamp
    public func getAllOperations() -> [SecurityOperation] {
        queue.sync {
            operations.sorted { $0.timestamp > $1.timestamp }
        }
    }

    /// Retrieves operations filtered by status
    /// - Parameter status: The status to filter by
    /// - Returns: An array of matching security operations
    public func getOperations(withStatus status: SecurityOperationStatus) -> [SecurityOperation] {
        queue.sync {
            operations.filter { $0.status == status }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }
}
