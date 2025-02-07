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
    public static func validateService<T>(
        _ serviceType: T.Type,
        logger: LoggerProtocol
    ) -> Result<Void, Error> {
        do {
            switch serviceType {
            case is SecurityServiceProtocol.Type:
                try createSecurityService(logger: logger).validate()
            case is KeychainServiceProtocol.Type:
                try createKeychainService(logger: logger).validate()
            case is BookmarkServiceProtocol.Type:
                let security = createSecurityService(logger: logger)
                let keychain = createKeychainService(logger: logger)
                try createBookmarkService(
                    logger: logger,
                    securityService: security,
                    keychainService: keychain
                ).validate()
            case is ResticXPCProtocol.Type:
                let security = createSecurityService(logger: logger)
                try createXPCService(
                    logger: logger,
                    securityService: security
                ).validate()
            case is BackupServiceProtocol.Type:
                let security = createSecurityService(logger: logger)
                let xpc = createXPCService(logger: logger, securityService: security)
                try createBackupService(
                    logger: logger,
                    securityService: security,
                    xpcService: xpc
                ).validate()
            case is RestoreServiceProtocol.Type:
                let security = createSecurityService(logger: logger)
                let xpc = createXPCService(logger: logger, securityService: security)
                try createRestoreService(
                    logger: logger,
                    securityService: security,
                    xpcService: xpc
                ).validate()
            case is ResticCommandServiceProtocol.Type:
                let security = createSecurityService(logger: logger)
                let xpc = createXPCService(logger: logger, securityService: security)
                try createResticCommandService(
                    logger: logger,
                    securityService: security,
                    xpcService: xpc
                ).validate()
            default:
                throw ServiceError.invalidServiceType(String(describing: serviceType))
            }
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
