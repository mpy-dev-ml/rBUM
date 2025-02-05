//
//  DummyXPCService.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Dummy XPC service used to break circular dependency during initialization
internal final class DummyXPCService: NSObject, ResticXPCServiceProtocol {
    // MARK: - Properties
    private let logger: LoggerProtocol
    public private(set) var isHealthy: Bool = false
    
    // MARK: - Initialization
    init(logger: LoggerProtocol) {
        self.logger = logger
        super.init()
    }
    
    // MARK: - ResticXPCServiceProtocol Implementation
    func ping() async -> Bool? {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        return nil
    }
    
    func initializeRepository(at url: URL, username: String, password: String) async throws {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        throw ServiceError.operationFailed
    }
    
    func backup(from source: URL, to destination: URL, username: String, password: String) async throws {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        throw ServiceError.operationFailed
    }
    
    func listSnapshots(username: String, password: String) async throws -> [String] {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        throw ServiceError.operationFailed
    }
    
    func restore(from source: URL, to destination: URL, username: String, password: String) async throws {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        throw ServiceError.operationFailed
    }
    
    // MARK: - HealthCheckable Implementation
    func performHealthCheck() async -> Bool {
        false
    }
}
