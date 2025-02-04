//
//  ServiceFactory.swift
//  Core
//
//  Created by Matthew Yeager on 04/02/2025.
//


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
public class DefaultServiceFactory: ServiceFactory {
    public static let shared = DefaultServiceFactory()
    
    private init() {}
    
    public func createLogger(category: String) -> LoggerProtocol {
        LoggerFactory.createLogger(category: category)
    }
    
    public func createSecurityService() -> SecurityServiceProtocol {
        // Create a standalone security service first
        let securityService = SecurityService(
            logger: createLogger(category: "SecurityService"),
            xpcService: createResticXPCService()
        )
        return securityService
    }
    
    private func createResticXPCService() -> ResticXPCServiceProtocol {
        ResticXPCService(
            logger: createLogger(category: "ResticXPCService"),
            securityService: SecurityService(
                logger: createLogger(category: "SecurityService"),
                xpcService: DummyXPCService(logger: createLogger(category: "DummyXPCService"))
            )
        ) as! ResticXPCServiceProtocol
    }
    
    public func createKeychainService() -> KeychainServiceProtocol {
        KeychainService(
            logger: createLogger(category: "KeychainService"),
            securityService: createSecurityService()
        )
    }
    
    public func createResticService() -> ResticServiceProtocol {
        ResticXPCService(
            logger: createLogger(category: "ResticService"),
            securityService: createSecurityService()
        )
    }
}
