//
//  ServiceFactory.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Factory for creating services with appropriate implementations based on build configuration
///
/// In DEBUG builds, this factory returns development mock services from Core/Sources/Services/Development
/// In RELEASE builds, it returns the default production implementations
public enum ServiceFactory {
    private static let developmentConfiguration = DevelopmentConfiguration()
    
    /// Create security service with appropriate implementation
    /// - Parameter logger: Logger for the service
    /// - Returns: SecurityServiceProtocol implementation
    public static func createSecurityService(logger: LoggerProtocol) -> SecurityServiceProtocol {
        #if DEBUG
        return DevelopmentSecurityService(
            logger: logger,
            configuration: developmentConfiguration
        )
        #else
        return DefaultSecurityService(logger: logger)
        #endif
    }
    
    /// Create keychain service with appropriate implementation
    /// - Parameter logger: Logger for the service
    /// - Returns: KeychainServiceProtocol implementation
    public static func createKeychainService(logger: LoggerProtocol) -> KeychainServiceProtocol {
        #if DEBUG
        return DevelopmentKeychainService(
            logger: logger,
            configuration: developmentConfiguration
        )
        #else
        return KeychainService(logger: logger)
        #endif
    }
    
    /// Create bookmark service with appropriate implementation
    /// - Parameters:
    ///   - logger: Logger for the service
    ///   - securityService: Security service dependency
    ///   - keychainService: Keychain service dependency
    /// - Returns: BookmarkServiceProtocol implementation
    public static func createBookmarkService(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) -> BookmarkServiceProtocol {
        #if DEBUG
        return DevelopmentBookmarkService(
            logger: logger,
            configuration: developmentConfiguration
        )
        #else
        return BookmarkService(
            logger: logger,
            securityService: securityService,
            keychainService: keychainService
        )
        #endif
    }
    
    /// Create XPC service with appropriate implementation
    /// - Parameters:
    ///   - logger: Logger for the service
    ///   - securityService: Security service dependency
    /// - Returns: ResticXPCProtocol implementation
    public static func createXPCService(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol
    ) -> ResticXPCProtocol {
        #if DEBUG
        return DevelopmentXPCService(
            logger: logger,
            configuration: developmentConfiguration
        )
        #else
        return CircuitBreakerXPCService(
            logger: logger,
            securityService: securityService
        )
        #endif
    }
}
