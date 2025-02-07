import Foundation

extension ServiceFactory {
    // MARK: - Service Creation
    
    /// Create security service with appropriate implementation
    /// - Parameter logger: Logger for the service
    /// - Returns: SecurityServiceProtocol implementation
    public static func createSecurityService(logger: LoggerProtocol) -> SecurityServiceProtocol {
        #if DEBUG
            return configuration.developmentEnabled
                ? DevelopmentSecurityService(
                    logger: logger,
                    configuration: developmentConfiguration
                )
                : DefaultSecurityService(logger: logger)
        #else
            return DefaultSecurityService(logger: logger)
        #endif
    }

    /// Create keychain service with appropriate implementation
    /// - Parameter logger: Logger for the service
    /// - Returns: KeychainServiceProtocol implementation
    public static func createKeychainService(logger: LoggerProtocol) -> KeychainServiceProtocol {
        #if DEBUG
            return configuration.developmentEnabled
                ? DevelopmentKeychainService(
                    logger: logger,
                    configuration: developmentConfiguration
                )
                : KeychainService(logger: logger)
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
            return configuration.developmentEnabled
                ? DevelopmentBookmarkService(
                    logger: logger,
                    configuration: developmentConfiguration
                )
                : BookmarkService(
                    logger: logger,
                    securityService: securityService,
                    keychainService: keychainService
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
            return configuration.developmentEnabled
                ? DevelopmentXPCService(
                    logger: logger,
                    configuration: developmentConfiguration
                )
                : CircuitBreakerXPCService(
                    logger: logger,
                    securityService: securityService
                )
        #else
            return configuration.circuitBreakersEnabled
                ? CircuitBreakerXPCService(
                    logger: logger,
                    securityService: securityService
                )
                : ResticXPCService(
                    logger: logger,
                    securityService: securityService
                )
        #endif
    }
    
    /// Create backup service with appropriate implementation
    /// - Parameters:
    ///   - logger: Logger for the service
    ///   - securityService: Security service dependency
    ///   - xpcService: XPC service dependency
    /// - Returns: BackupServiceProtocol implementation
    public static func createBackupService(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        xpcService: ResticXPCProtocol
    ) -> BackupServiceProtocol {
        BackupService(
            logger: logger,
            securityService: securityService,
            xpcService: xpcService
        )
    }
    
    /// Create restore service with appropriate implementation
    /// - Parameters:
    ///   - logger: Logger for the service
    ///   - securityService: Security service dependency
    ///   - xpcService: XPC service dependency
    /// - Returns: RestoreServiceProtocol implementation
    public static func createRestoreService(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        xpcService: ResticXPCProtocol
    ) -> RestoreServiceProtocol {
        RestoreService(
            logger: logger,
            securityService: securityService,
            xpcService: xpcService
        )
    }
    
    /// Create Restic command service with appropriate implementation
    /// - Parameters:
    ///   - logger: Logger for the service
    ///   - securityService: Security service dependency
    ///   - xpcService: XPC service dependency
    /// - Returns: ResticCommandServiceProtocol implementation
    public static func createResticCommandService(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        xpcService: ResticXPCProtocol
    ) -> ResticCommandServiceProtocol {
        ResticCommandService(
            logger: logger,
            securityService: securityService,
            xpcService: xpcService
        )
    }
}
