import Foundation
import os.log

/// Tracks security metrics
@available(macOS 13.0, *)
public struct SecurityMetrics {
    private(set) var accessCount: Int = 0
    private(set) var permissionCount: Int = 0
    private(set) var bookmarkCount: Int = 0
    private(set) var xpcCount: Int = 0
    private(set) var failureCount: Int = 0
    private(set) var activeAccessCount: Int = 0
    private(set) var operationHistory: [SecurityOperation] = []
    
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    mutating func recordAccess(success: Bool = true, error: String? = nil) {
        accessCount += 1
        if !success { failureCount += 1 }
    }
    
    mutating func recordPermission(success: Bool = true, error: String? = nil) {
        permissionCount += 1
        if !success { failureCount += 1 }
    }
    
    mutating func recordBookmark(success: Bool = true, error: String? = nil) {
        bookmarkCount += 1
        if !success { failureCount += 1 }
    }
    
    mutating func recordXPC(success: Bool = true, error: String? = nil) {
        xpcCount += 1
        if !success { failureCount += 1 }
    }
    
    mutating func recordOperation(
        _ operation: SecurityOperation
    ) {
        operationHistory.append(operation)
        if operationHistory.count > 100 {
            operationHistory.removeFirst()
        }
    }
    
    mutating func incrementActiveAccess() {
        activeAccessCount += 1
    }
    
    mutating func decrementActiveAccess() {
        activeAccessCount = max(0, activeAccessCount - 1)
    }
    
    mutating func recordAccessEnd() {
        decrementActiveAccess()
    }
}
