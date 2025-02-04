//
//  DummyXPCService.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//


//
//  DummyXPCService.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Dummy XPC service used to break circular dependency during initialization
internal class DummyXPCService: NSObject, ResticXPCServiceProtocol {
    private let logger: LoggerProtocol
    
    init(logger: LoggerProtocol) {
        self.logger = logger
        super.init()
    }
    
    func connect() async throws {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        throw ServiceError.operationFailed
    }
    
    func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        throw ServiceError.operationFailed
    }
    
    func startAccessing(_ url: URL) -> Bool {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        return false
    }
    
    func stopAccessing(_ url: URL) {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
    }
    
    func validatePermissions() async throws -> Bool {
        logger.warning("Dummy XPC service called - this should not happen in production",
                      file: #file, function: #function, line: #line)
        return false
    }
}
