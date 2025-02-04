//
//  BaseSandboxedService.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Base class for services requiring sandbox compliance
open class BaseSandboxedService {
    // MARK: - Properties
    public let logger: LoggerProtocol
    public let securityService: SecurityServiceProtocol
    
    // MARK: - Initialization
    public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.logger = logger
        self.securityService = securityService
    }
    
    // MARK: - Public Methods
    open func startAccessing(_ url: URL) -> Bool {
        do {
            return try securityService.startAccessing(url)
        } catch {
            logger.error("Failed to start accessing \(url.path): \(error.localizedDescription)",
                        file: #file,
                        function: #function,
                        line: #line)
            return false
        }
    }
    
    open func stopAccessing(_ url: URL) {
        Task {
            do {
                try await securityService.stopAccessing(url)
            } catch {
                logger.error("Failed to stop accessing \(url.path): \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
            }
        }
    }
}
