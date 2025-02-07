import Foundation
import os.log

/// Records security operations
@available(macOS 13.0, *)
public struct SecurityOperationRecorder {
    private let logger: Logger
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
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
