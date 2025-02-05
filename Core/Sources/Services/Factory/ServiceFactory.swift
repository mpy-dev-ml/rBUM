//
//  ServiceFactory.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Factory protocol for creating services
public protocol ServiceFactory {
    func createLogger(category: String) -> LoggerProtocol
    func createSecurityService() -> SecurityServiceProtocol
    func createKeychainService() -> KeychainServiceProtocol
    func createResticService() -> ResticServiceProtocol
}

/// Default implementation of ServiceFactory
public final class DefaultServiceFactory: ServiceFactory {
    public static let shared = DefaultServiceFactory()
    
    private init() {}
    
    public func createLogger(category: String) -> LoggerProtocol {
        OSLogger(category: category)
    }
    
    public func createSecurityService() -> SecurityServiceProtocol {
        let logger = createLogger(category: "Security")
        let dummyXPC = DummyXPCService(logger: logger)
        return SecurityService(logger: logger, xpcService: dummyXPC)
    }
    
    public func createKeychainService() -> KeychainServiceProtocol {
        let logger = createLogger(category: "Keychain")
        let security = createSecurityService()
        // Explicitly specify we want KeychainService's init
        return KeychainService.init(logger: logger, securityService: security)
    }
    
    public func createResticService() -> ResticServiceProtocol {
        let logger = createLogger(category: "Restic")
        // Use ResticCommandService instead of ResticXPCService
        return ResticCommandService(logger: logger)
    }
}
