import Foundation

/// Represents a security operation with metadata
@available(macOS 13.0, *)
public struct SecurityOperation: Hashable {
    public let url: URL
    public let operationType: SecurityOperationType
    public let timestamp: Date
    public let status: SecurityOperationStatus
    public let error: String?
    
    public init(
        url: URL,
        operationType: SecurityOperationType,
        timestamp: Date,
        status: SecurityOperationStatus,
        error: String? = nil
    ) {
        self.url = url
        self.operationType = operationType
        self.timestamp = timestamp
        self.status = status
        self.error = error
    }
    
    public static func == (lhs: SecurityOperation, rhs: SecurityOperation) -> Bool {
        return lhs.url == rhs.url &&
               lhs.operationType == rhs.operationType &&
               lhs.timestamp == rhs.timestamp
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(operationType)
        hasher.combine(timestamp)
    }
}
