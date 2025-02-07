import Foundation

extension ServiceFactory {
    // MARK: - Lifecycle Management
    
    /// Starts all services created by the factory
    /// - Parameter logger: Logger for lifecycle events
    /// - Returns: Result indicating success or failure with error details
    public static func startServices(logger: LoggerProtocol) -> Result<Void, Error> {
        do {
            // Create and start core services
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
            
            try security.start()
            try keychain.start()
            try bookmark.start()
            try xpc.start()
            
            // Create and start dependent services
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
            
            try backup.start()
            try restore.start()
            try resticCommand.start()
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// Stops all services created by the factory
    /// - Parameter logger: Logger for lifecycle events
    /// - Returns: Result indicating success or failure with error details
    public static func stopServices(logger: LoggerProtocol) -> Result<Void, Error> {
        do {
            // Create services (they may already exist, but we need references)
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
            
            // Stop in reverse order of dependencies
            try resticCommand.stop()
            try restore.stop()
            try backup.stop()
            try xpc.stop()
            try bookmark.stop()
            try keychain.stop()
            try security.stop()
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    /// Restarts all services created by the factory
    /// - Parameter logger: Logger for lifecycle events
    /// - Returns: Result indicating success or failure with error details
    public static func restartServices(logger: LoggerProtocol) -> Result<Void, Error> {
        do {
            // Stop all services
            if case .failure(let error) = stopServices(logger: logger) {
                throw error
            }
            
            // Start all services
            if case .failure(let error) = startServices(logger: logger) {
                throw error
            }
            
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
