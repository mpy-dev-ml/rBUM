import Core
import Foundation

/// Handles app setup and dependency injection
enum AppSetup {
    // MARK: - Types
    
    struct CoreDependencies {
        let fileManager: FileManagerProtocol
        let dateProvider: DateProviderProtocol
        let notificationCenter: NotificationCenter
        let repositoryLock: NSLock
    }
    
    struct SecurityServices {
        let securityService: SecurityServiceProtocol
        let keychainService: KeychainServiceProtocol
        let bookmarkService: BookmarkServiceProtocol
        let sandboxMonitor: SandboxMonitor
        let xpcService: ResticXPCServiceProtocol
    }
    
    // MARK: - Setup Methods
    
    static func setupCoreDependencies() -> CoreDependencies {
        CoreDependencies(
            fileManager: DefaultFileManager(),
            dateProvider: DateProvider(),
            notificationCenter: .default,
            repositoryLock: NSLock()
        )
    }
    
    static func setupSecurityServices(_ dependencies: CoreDependencies) -> SecurityServices {
        let logger = LoggerFactory.createLogger(category: "SecurityServices")
        let securityService = ServiceFactory.createSecurityService(logger: logger)
        let keychainService = ServiceFactory.createKeychainService(logger: logger)
        let bookmarkService = ServiceFactory.createBookmarkService(
            logger: logger,
            securityService: securityService,
            keychainService: keychainService
        )
        
        let sandboxMonitor = SandboxMonitor(
            logger: logger,
            securityService: securityService
        )
        
        let xpcService = ServiceFactory.createXPCService(
            logger: logger,
            securityService: securityService
        ) as! ResticXPCServiceProtocol
        
        return SecurityServices(
            securityService: securityService,
            keychainService: keychainService,
            bookmarkService: bookmarkService,
            sandboxMonitor: sandboxMonitor,
            xpcService: xpcService
        )
    }
    
    static func setupCredentialsManager(
        dependencies: CoreDependencies,
        keychainService: KeychainServiceProtocol
    ) -> KeychainCredentialsManagerProtocol {
        let logger = LoggerFactory.createLogger(category: "CredentialsManager")
        return KeychainCredentialsManager(
            logger: logger,
            keychainService: keychainService,
            dateProvider: dependencies.dateProvider,
            notificationCenter: dependencies.notificationCenter
        )
    }
    
    static func setupRepositoryStorage(
        _ fileManager: FileManagerProtocol
    ) -> RepositoryStorageProtocol {
        let logger = LoggerFactory.createLogger(category: "RepositoryStorage")
        do {
            return try DefaultRepositoryStorage(
                fileManager: fileManager,
                logger: logger
            )
        } catch {
            logger.error(
                "Failed to initialize repository storage: \(error.localizedDescription)",
                privacy: .public
            )
            fatalError("Failed to initialize repository storage: \(error.localizedDescription)")
        }
    }
    
    static func setupResticService(
        dependencies: CoreDependencies,
        securityServices: SecurityServices
    ) -> ResticCommandServiceProtocol {
        let logger = LoggerFactory.createLogger(category: "ResticService")
        return ResticCommandService(
            logger: logger,
            securityService: securityServices.securityService,
            xpcService: securityServices.xpcService,
            keychainService: securityServices.keychainService
        ) as! any ResticCommandServiceProtocol
    }
    
    static func setupRepositoryCreationService(
        dependencies: CoreDependencies,
        securityServices: SecurityServices
    ) -> RepositoryCreationServiceProtocol {
        let logger = LoggerFactory.createLogger(category: "RepositoryCreation")
        return DefaultRepositoryCreationService(
            logger: logger,
            securityService: securityServices.securityService,
            bookmarkService: securityServices.bookmarkService,
            keychainService: securityServices.keychainService
        ) as! any RepositoryCreationServiceProtocol
    }
    
    static func setupFileSearchService(
        dependencies: CoreDependencies,
        securityServices: SecurityServices,
        resticService: ResticCommandServiceProtocol,
        logger: LoggerProtocol
    ) -> FileSearchServiceProtocol {
        FileSearchService(
            resticService: resticService,
            repositoryLock: dependencies.repositoryLock,
            logger: logger
        )
    }
    
    static func setupRestoreService(
        dependencies: CoreDependencies,
        securityServices: SecurityServices,
        resticService: ResticCommandServiceProtocol,
        logger: LoggerProtocol
    ) -> RestoreServiceProtocol {
        RestoreService(
            logger: logger,
            securityService: resticService as! SecurityServiceProtocol,
            resticService: resticService,
            keychainService: securityServices.keychainService,
            fileManager: dependencies.fileManager
        )
    }
}
