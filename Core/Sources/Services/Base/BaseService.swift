//
//  BaseService.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import os.log

/// Base class providing common service functionality
public class BaseService: NSObject, LoggingService {
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

public enum ServiceError: LocalizedError {
    case retryFailed(operation: String, underlyingError: Error?)
    case operationFailed
    
    public var errorDescription: String? {
        switch self {
        case .retryFailed(let operation, let error):
            if let error = error {
                return "Operation '\(operation)' failed after multiple attempts: \(error.localizedDescription)"
            }
            return "Operation '\(operation)' failed after multiple attempts"
        case .operationFailed:
            return "Operation failed"
        }
    }
}
