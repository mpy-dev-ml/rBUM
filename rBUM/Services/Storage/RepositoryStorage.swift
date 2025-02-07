//
//  RepositoryStorage.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Core
import Foundation

/// Manages persistent storage of repository information and security-scoped bookmarks
final class RepositoryStorage: Core.StorageServiceProtocol {
    func save(_ data: Data, forKey key: String) throws {
        logger.debug("Saving data for key: \(key)", file: #file, function: #function, line: #line)
        do {
            try data.write(to: storageURL, options: .atomic)
        } catch {
            logger.error(
                "Failed to save data: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw StorageError.fileOperationFailed("save")
        }
    }

    func load(forKey key: String) throws -> Data {
        logger.debug("Loading data for key: \(key)", file: #file, function: #function, line: #line)
        do {
            return try Data(contentsOf: storageURL)
        } catch {
            logger.error(
                "Failed to load data: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw StorageError.fileOperationFailed("load")
        }
    }

    func delete(forKey key: String) throws {
        logger.debug("Deleting data for key: \(key)", file: #file, function: #function, line: #line)
        do {
            try fileManager.removeItem(at: storageURL)
        } catch {
            logger.error(
                "Failed to delete data: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw StorageError.fileOperationFailed("delete")
        }
    }

    // MARK: - Private Properties

    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenter
    private let storageDirectory: URL

    private var storageURL: URL {
        storageDirectory.appendingPathComponent("repositories.json")
    }

    // MARK: - Initialization

    init(
        fileManager: FileManagerProtocol = FileManager.default as! FileManagerProtocol,
        logger: LoggerProtocol = OSLogger(category: "storage"),
        securityService: SecurityServiceProtocol = {
            let logger = OSLogger(category: "security")
            // Step 1: Create temporary security service with mock XPC
            let tempSecurityService = SecurityService(
                logger: logger,
                xpcService: MockResticXPCService()
            )

            // Step 2: Create real XPC service using temporary security service
            let xpcService = ResticXPCService(
                logger: logger,
                securityService: tempSecurityService
            )

            // Step 3: Create final security service with real XPC service
            return SecurityService(
                logger: logger,
                xpcService: xpcService as! ResticXPCServiceProtocol
            )
        }(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenter = .default
    ) throws {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter

        // Get application support directory
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else {
            throw StorageError.fileOperationFailed("Failed to get application support directory")
        }

        // Create storage directory
        storageDirectory = appSupport.appendingPathComponent("dev.mpy.rBUM", isDirectory: true)
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        logger.debug("Storage initialized at \(storageDirectory.path)", file: #file, function: #function, line: #line)
    }
}

// MARK: - Repository Management

extension RepositoryStorage {
    func saveRepository(_ repository: Repository) throws {
        logger.debug("Saving repository: \(repository.name)", file: #file, function: #function, line: #line)

        do {
            let data = try JSONEncoder().encode(repository)
            try save(data, forKey: repository.id.uuidString)
            notificationCenter.post(name: .repositoryUpdated, object: repository)
        } catch {
            logger.error(
                "Failed to save repository: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw StorageError.fileOperationFailed("save repository")
        }
    }

    func loadRepository(withId id: UUID) throws -> Repository {
        logger.debug("Loading repository with ID: \(id)", file: #file, function: #function, line: #line)

        do {
            let data = try load(forKey: id.uuidString)
            return try JSONDecoder().decode(Repository.self, from: data)
        } catch {
            logger.error(
                "Failed to load repository: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw StorageError.fileOperationFailed("load repository")
        }
    }

    func deleteRepository(_ repository: Repository) throws {
        logger.debug("Deleting repository: \(repository.name)", file: #file, function: #function, line: #line)

        do {
            try delete(forKey: repository.id.uuidString)
            notificationCenter.post(name: .repositoryDeleted, object: repository)
        } catch {
            logger.error(
                "Failed to delete repository: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw StorageError.fileOperationFailed("delete repository")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let repositoryUpdated = Notification.Name("dev.mpy.rBUM.repositoryUpdated")
    static let repositoryDeleted = Notification.Name("dev.mpy.rBUM.repositoryDeleted")
}
