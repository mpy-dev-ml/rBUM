//
//  BaseService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import os.log

/// Base class providing common service functionality
open class BaseService: NSObject, LoggingService {
    public let logger: LoggerProtocol
    
    public init(logger: LoggerProtocol) {
        self.logger = logger
        super.init()
    }
    
    /// Execute an operation with retry logic
    public func withRetry<T>(
        attempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: String,
        action: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                return try await action()
            } catch {
                lastError = error
                logger.warning("Attempt \(attempt)/\(attempts) failed for operation '\(operation)': \(error.localizedDescription)",
                             file: #file,
                             function: #function,
                             line: #line)
                
                if attempt < attempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw ServiceError.retryFailed(operation: operation, underlyingError: lastError)
    }
}
