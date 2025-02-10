import Core
import Foundation

/// Default repository storage implementation for macOS
final class DefaultRepositoryStorage: RepositoryStorageProtocol {
    // MARK: - Properties

    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let storageURL: URL
    private let securityService: SecurityServiceProtocol
    private let minimumRequiredSpace: UInt64
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(
        fileManager: FileManagerProtocol = DefaultFileManager(),
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "RepositoryStorage"),
        storageURL: URL? = nil,
        securityService: SecurityServiceProtocol = DefaultSecurityService(),
        minimumRequiredSpace: UInt64 = 1024 * 1024 * 1024 // 1 GB
    ) throws {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.minimumRequiredSpace = minimumRequiredSpace
        encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        decoder = JSONDecoder()

        if let url = storageURL {
            self.storageURL = url
        } else {
            // Get application support directory
            guard let appSupport = try? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            else {
                logger.error("Could not access application support directory")
                throw RepositoryError.invalidDirectory
            }

            // Create repositories directory if needed
            self.storageURL = appSupport.appendingPathComponent("Repositories", isDirectory: true)
        }

        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

        logger.debug("Storage initialised", metadata: ["path": .string(storageURL.path)])
    }

    // MARK: - Repository Management

    func save(_ repository: Repository) async throws {
        logger.debug("Saving repository", metadata: [
            "id": .string(repository.id.uuidString),
            "name": .string(repository.name),
        ])

        try await validateRepository(repository)

        do {
            let data = try encoder.encode(repository)
            let fileURL = storageURL.appendingPathComponent("\(repository.id.uuidString).json")
            try data.write(to: fileURL, options: .atomic)

            logger.info("Saved repository successfully", metadata: [
                "id": .string(repository.id.uuidString),
            ])
        } catch {
            logger.error("Failed to save repository", metadata: [
                "error": .string(error.localizedDescription),
            ])
            throw RepositoryError.saveFailed(error)
        }
    }

    func loadAll() async throws -> [Repository] {
        logger.debug("Loading all repositories")

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: storageURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let repositories = try contents
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> Repository? in
                    do {
                        let data = try Data(contentsOf: url)
                        return try decoder.decode(Repository.self, from: data)
                    } catch {
                        logger.error("Failed to load repository", metadata: [
                            "path": .string(url.path),
                            "error": .string(error.localizedDescription),
                        ])
                        return nil
                    }
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            logger.info("Loaded repositories", metadata: [
                "count": .string("\(repositories.count)"),
            ])
            return repositories

        } catch {
            logger.error("Failed to load repositories", metadata: [
                "error": .string(error.localizedDescription),
            ])
            throw RepositoryError.loadFailed(error)
        }
    }

    func delete(_ repository: Repository) async throws {
        logger.debug("Deleting repository", metadata: [
            "id": .string(repository.id.uuidString),
            "name": .string(repository.name),
        ])

        do {
            let fileURL = storageURL.appendingPathComponent("\(repository.id.uuidString).json")
            try fileManager.removeItem(at: fileURL)

            logger.info("Deleted repository successfully", metadata: [
                "id": .string(repository.id.uuidString),
            ])
        } catch {
            logger.error("Failed to delete repository", metadata: [
                "error": .string(error.localizedDescription),
            ])
            throw RepositoryError.deleteFailed(error)
        }
    }

    func updateStatus(_ repository: Repository, status: RepositoryStatus) async throws {
        logger.debug("Updating repository status", metadata: [
            "id": .string(repository.id.uuidString),
            "status": .string("\(status)"),
        ])

        do {
            var updated = repository
            updated.status = status
            updated.lastAccessed = Date()
            try await save(updated)

            logger.info("Updated repository status successfully", metadata: [
                "id": .string(repository.id.uuidString),
            ])
        } catch {
            logger.error("Failed to update repository status", metadata: [
                "error": .string(error.localizedDescription),
            ])
            throw RepositoryError.updateFailed(error)
        }
    }

    // MARK: - Repository Validation

    private func validateRepository(_ repository: Repository) async throws {
        try await validateBasicProperties(repository)
        try await validateCredentials(repository)
        try await validateLocation(repository)
    }

    private func validateBasicProperties(_ repository: Repository) async throws {
        guard !repository.name.isEmpty else {
            throw RepositoryError.invalidName("Repository name cannot be empty")
        }

        guard !repository.description.isEmpty else {
            throw RepositoryError.invalidDescription("Repository description cannot be empty")
        }

        guard repository.id != UUID() else {
            throw RepositoryError.invalidIdentifier("Repository ID cannot be empty")
        }
    }

    private func validateCredentials(_ repository: Repository) async throws {
        guard let credentials = repository.credentials else {
            throw RepositoryError.missingCredentials("Repository credentials are required")
        }

        guard !credentials.password.isEmpty else {
            throw RepositoryError.invalidCredentials("Repository password cannot be empty")
        }

        // Validate password complexity
        let passwordRegex = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{8,}$"
        guard credentials.password.range(of: passwordRegex, options: .regularExpression) != nil else {
            throw RepositoryError.invalidCredentials(
                """
                Password must be at least 8 characters and
                contain both letters and numbers
                """
            )
        }
    }

    private func validateLocation(_ repository: Repository) async throws {
        guard let url = repository.url else {
            throw RepositoryError.invalidLocation("Repository URL is required")
        }

        // Check if URL is accessible
        guard try await securityService.validateAccess(to: url) else {
            throw RepositoryError.inaccessibleLocation("Repository location is not accessible")
        }

        // Check if URL is writable
        guard try await securityService.validateWriteAccess(to: url) else {
            throw RepositoryError.readOnlyLocation("Repository location is read-only")
        }

        // Check available space
        let availableSpace = try await fileManager.availableSpace(at: url)
        guard availableSpace > minimumRequiredSpace else {
            throw RepositoryError.insufficientSpace("Repository location has insufficient space")
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case invalidDirectory
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)
    case updateFailed(Error)
    case invalidName(String)
    case invalidDescription(String)
    case invalidIdentifier(String)
    case missingCredentials(String)
    case invalidCredentials(String)
    case invalidLocation(String)
    case inaccessibleLocation(String)
    case readOnlyLocation(String)
    case insufficientSpace(String)

    var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            "Could not access repository storage directory"
        case let .saveFailed(error):
            "Failed to save repository: \(error.localizedDescription)"
        case let .loadFailed(error):
            "Failed to load repositories: \(error.localizedDescription)"
        case let .deleteFailed(error):
            "Failed to delete repository: \(error.localizedDescription)"
        case let .updateFailed(error):
            "Failed to update repository status: \(error.localizedDescription)"
        case let .invalidName(message):
            message
        case let .invalidDescription(message):
            message
        case let .invalidIdentifier(message):
            message
        case let .missingCredentials(message):
            message
        case let .invalidCredentials(message):
            message
        case let .invalidLocation(message):
            message
        case let .inaccessibleLocation(message):
            message
        case let .readOnlyLocation(message):
            message
        case let .insufficientSpace(message):
            message
        }
    }
}
