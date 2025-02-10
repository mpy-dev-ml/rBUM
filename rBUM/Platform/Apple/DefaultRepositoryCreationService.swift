import Core
import Foundation

/// Service for creating and managing default repository locations on macOS
public final class DefaultRepositoryCreationService: BaseSandboxedService, DefaultRepositoryCreationProtocol,
    HealthCheckable
{
    // MARK: - Properties

    private let bookmarkService: BookmarkServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let operationQueue: OperationQueue
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.defaultRepository", attributes: .concurrent)
    private var activeOperations: Set<UUID> = []

    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            activeOperations.isEmpty
        }
    }

    // MARK: - Initialization

    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        keychainService: KeychainServiceProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService

        operationQueue = OperationQueue()
        operationQueue.name = "dev.mpy.rBUM.defaultRepositoryQueue"
        operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - DefaultRepositoryCreationProtocol Implementation

    public func createDefaultRepository() async throws -> URL {
        let operationId = UUID()

        return try await measure("Create Default Repository") {
            // Track operation
            accessQueue.async(flags: .barrier) {
                self.activeOperations.insert(operationId)
            }

            defer {
                accessQueue.async(flags: .barrier) {
                    self.activeOperations.remove(operationId)
                }
            }

            do {
                // Get application support directory
                let appSupport = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )

                // Create repository directory
                let repositoryURL = appSupport.appendingPathComponent("Repositories", isDirectory: true)
                    .appendingPathComponent("Default", isDirectory: true)

                try await initializeRepository(at: repositoryURL)

                // Create and store bookmark
                let bookmark = try await bookmarkService.createBookmark(for: repositoryURL)
                try keychainService.storeBookmark(bookmark, for: repositoryURL)

                logger.info("Created default repository at \(repositoryURL.path)")
                return repositoryURL
            } catch {
                logger.error("Failed to create default repository: \(error.localizedDescription)")
                throw RepositoryCreationError.creationFailed(error.localizedDescription)
            }
        }
    }

    private func initializeRepository(at url: URL) async throws {
        try await createRepositoryDirectory(at: url)
        try await createSecurityBookmark(for: url)
    }

    private func createRepositoryDirectory(at url: URL) async throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func createSecurityBookmark(for url: URL) async throws {
        let bookmark = try await bookmarkService.createBookmark(for: url)
        try keychainService.storeBookmark(bookmark, for: url)
    }

    public func getDefaultRepositoryLocation() async throws -> URL? {
        try await measure("Get Default Repository Location") {
            do {
                // Get application support directory
                let appSupport = try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )

                let repositoryURL = appSupport.appendingPathComponent("Repositories", isDirectory: true)
                    .appendingPathComponent("Default", isDirectory: true)

                // Check if directory exists
                guard FileManager.default.fileExists(atPath: repositoryURL.path) else {
                    logger.info("Default repository not found")
                    return nil
                }

                // Validate bookmark
                guard try await bookmarkService.validateBookmark(for: repositoryURL) else {
                    logger.warning("Invalid bookmark for default repository")
                    return nil
                }

                return repositoryURL
            } catch {
                logger.error("Failed to get default repository location: \(error.localizedDescription)")
                return nil
            }
        }
    }

    public func validateDefaultRepository() async throws -> Bool {
        try await measure("Validate Default Repository") {
            do {
                guard let repositoryURL = try await getDefaultRepositoryLocation() else {
                    return false
                }

                // Check if directory exists
                guard FileManager.default.fileExists(atPath: repositoryURL.path) else {
                    return false
                }

                // Verify we can access the repository
                guard try await bookmarkService.startAccessing(repositoryURL) else {
                    return false
                }
                defer { try? bookmarkService.stopAccessing(repositoryURL) }

                // Check if we can write to the repository
                let testFileURL = repositoryURL.appendingPathComponent(".rBUM_test")
                guard FileManager.default.createFile(atPath: testFileURL.path, contents: nil) else {
                    return false
                }
                try FileManager.default.removeItem(at: testFileURL)

                return true
            } catch {
                logger.error(
                    "Repository validation failed: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }

    // MARK: - Health Check

    public func performHealthCheck() async -> Bool {
        await measure("Repository Creation Health Check") {
            do {
                // Check bookmark service
                guard await bookmarkService.performHealthCheck() else {
                    logger.error(
                        "Bookmark service health check failed",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                    return false
                }

                // Check keychain service
                guard await keychainService.performHealthCheck() else {
                    logger.error(
                        "Keychain service health check failed",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                    return false
                }

                return true
            } catch {
                logger.error(
                    "Health check failed: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }
}

// MARK: - Repository Creation Errors

public enum RepositoryCreationError: LocalizedError {
    case creationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .creationFailed(message):
            "Repository creation failed: \(message)"
        }
    }
}
