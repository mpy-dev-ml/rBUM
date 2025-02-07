import Foundation
import os.log

/// Records and manages security operations for development and testing
@available(macOS 13.0, *)
public final class SecurityOperationRecorder {
    /// Represents a security operation with metadata
    struct SecurityOperation: Hashable {
        let url: URL
        let operationType: OperationType
        let timestamp: Date
        let status: OperationStatus
        let error: String?
        
        enum OperationType: String {
            case access
            case permission
            case bookmark
            case xpc
        }
        
        enum OperationStatus: String {
            case success
            case failure
            case pending
        }
        
        static func == (lhs: SecurityOperation, rhs: SecurityOperation) -> Bool {
            return lhs.url == rhs.url &&
                   lhs.operationType == rhs.operationType &&
                   lhs.timestamp == rhs.timestamp
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(operationType)
            hasher.combine(timestamp)
        }
    }
    
    private let logger: Logger
    private let queue = DispatchQueue(label: "dev.mpy.rbum.security.operations")
    private var operations: Set<SecurityOperation> = []
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func recordOperation(
        url: URL,
        type: SecurityOperation.OperationType,
        status: SecurityOperation.OperationStatus,
        error: String? = nil
    ) {
        queue.sync {
            let operation = SecurityOperation(
                url: url,
                operationType: type,
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
    
    func getOperations(for url: URL) -> [SecurityOperation] {
        queue.sync {
            return operations.filter { $0.url == url }
                .sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    func clearOperations() {
        queue.sync {
            operations.removeAll()
        }
    }
}
