import Foundation
import os.log

/// Represents a security operation with metadata
@objc public class SecurityOperation: NSObject {
    @objc public let url: URL
    @objc public let type: SecurityOperationType
    @objc public let timestamp: Date
    @objc public let status: SecurityOperationStatus
    @objc public let error: String?

    @objc public init(
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
        super.init()
    }

    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SecurityOperation else { return false }
        return url == other.url &&
            type == other.type &&
            timestamp == other.timestamp
    }

    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(url)
        hasher.combine(type)
        hasher.combine(timestamp)
        return hasher.finalize()
    }
}

/// Represents the type of a security operation
@objc public enum SecurityOperationType: Int {
    case access = 1
    case permission = 2
    case bookmark = 3
    case xpc = 4
}

/// Represents the status of a security operation
@objc public enum SecurityOperationStatus: Int {
    case success = 1
    case failure = 2
    case pending = 3
}

/// Records and manages security operations for development and testing
@available(macOS 13.0, *)
@objc public final class SecurityOperationRecorder: NSObject {
    private let logger: Logger
    private let queue = DispatchQueue(label: "dev.mpy.rbum.security.operations")
    private var operations: [SecurityOperation] = []

    @objc public init(logger: Logger) {
        self.logger = logger
        super.init()
    }

    @objc public func recordOperation(
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
            operations.append(operation)

            logger.info("""
            Recording security operation:
            Type: \(type.rawValue)
            URL: \(url.path)
            Status: \(status.rawValue)
            \(error.map { "Error: \($0)" } ?? "")
            """)
        }
    }

    @objc public func getOperations(for url: URL) -> [SecurityOperation] {
        queue.sync {
            operations.filter { $0.url == url }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }

    @objc public func clearOperations() {
        queue.sync {
            operations.removeAll()
        }
    }

    @objc public func getAllOperations() -> [SecurityOperation] {
        queue.sync {
            operations.sorted { $0.timestamp > $1.timestamp }
        }
    }

    @objc public func getOperations(withStatus status: SecurityOperationStatus) -> [SecurityOperation] {
        queue.sync {
            operations.filter { $0.status == status }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }
}
