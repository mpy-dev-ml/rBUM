import Foundation

extension ServiceFactory {
    // MARK: - Validation

    /// Validates that all required services can be created and initialized
    /// - Parameter logger: Logger for validation
    /// - Returns: Result indicating success or failure with error details
    public static func validateServices(logger: LoggerProtocol) -> Result<Void, Error> {
        do {
            // Create core services
            let security = createSecurityService(logger: logger)
            let keychain = createKeychainService(logger: logger)
            let bookmark = createBookmarkService(
                logger: logger,
                securityService: security,
                keychainService: keychain
            )
            let xpc = createXPCService(
                logger: logger,
                securityService: security
            )

            // Validate core services
            try security.validate()
            try keychain.validate()
            try bookmark.validate()
            try xpc.validate()

            // Create and validate dependent services
            let backup = createBackupService(
                logger: logger,
                securityService: security,
                xpcService: xpc
            )
            let restore = createRestoreService(
                logger: logger,
                securityService: security,
                xpcService: xpc
            )
            let resticCommand = createResticCommandService(
                logger: logger,
                securityService: security,
                xpcService: xpc
            )

            try backup.validate()
            try restore.validate()
            try resticCommand.validate()

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Validates that a specific service type can be created and initialized
    /// - Parameters:
    ///   - serviceType: Type of service to validate
    ///   - logger: Logger for validation
    /// - Returns: Result indicating success or failure with error details
    public static func validateService(
        _ serviceType: (some Any).Type,
        logger: LoggerProtocol
    ) -> Result<Void, Error> {
        do {
            try validateSpecificService(serviceType, logger: logger)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    /// Validates a specific service type
    /// - Parameters:
    ///   - serviceType: Type of service to validate
    ///   - logger: Logger for validation
    private static func validateSpecificService(
        _ serviceType: (some Any).Type,
        logger: LoggerProtocol
    ) throws {
        switch serviceType {
        case is SecurityServiceProtocol.Type:
            try validateSecurityService(logger: logger)
        case is KeychainServiceProtocol.Type:
            try validateKeychainService(logger: logger)
        case is BookmarkServiceProtocol.Type:
            try validateBookmarkService(logger: logger)
        case is ResticXPCProtocol.Type:
            try validateXPCService(logger: logger)
        case is BackupServiceProtocol.Type:
            try validateBackupService(logger: logger)
        case is RestoreServiceProtocol.Type:
            try validateRestoreService(logger: logger)
        default:
            throw ServiceError.unsupportedServiceType(String(describing: serviceType))
        }
    }

    /// Validates security service
    private static func validateSecurityService(logger: LoggerProtocol) throws {
        try createSecurityService(logger: logger).validate()
    }

    /// Validates keychain service
    private static func validateKeychainService(logger: LoggerProtocol) throws {
        try createKeychainService(logger: logger).validate()
    }

    /// Validates bookmark service
    private static func validateBookmarkService(logger: LoggerProtocol) throws {
        let security = createSecurityService(logger: logger)
        let keychain = createKeychainService(logger: logger)
        try createBookmarkService(
            logger: logger,
            securityService: security,
            keychainService: keychain
        ).validate()
    }

    /// Validates XPC service
    private static func validateXPCService(logger: LoggerProtocol) throws {
        let security = createSecurityService(logger: logger)
        try createXPCService(
            logger: logger,
            securityService: security
        ).validate()
    }

    /// Validates backup service
    private static func validateBackupService(logger: LoggerProtocol) throws {
        let security = createSecurityService(logger: logger)
        let xpc = createXPCService(logger: logger, securityService: security)
        try createBackupService(
            logger: logger,
            securityService: security,
            xpcService: xpc
        ).validate()
    }

    /// Validates restore service
    private static func validateRestoreService(logger: LoggerProtocol) throws {
        let security = createSecurityService(logger: logger)
        let xpc = createXPCService(logger: logger, securityService: security)
        try createRestoreService(
            logger: logger,
            securityService: security,
            xpcService: xpc
        ).validate()
    }
}
