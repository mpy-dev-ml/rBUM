import Foundation
import Core

/// Manages persistent storage of repository information and security-scoped bookmarks
final class RepositoryStorage: StorageServiceProtocol {
    // MARK: - Private Properties
    
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let securityService: SecurityServiceProtocol
    private let dateProvider: DateProviderProtocol
    private let notificationCenter: NotificationCenterProtocol
    private let storageDirectory: URL
    
    private var storageURL: URL { 
        storageDirectory.appendingPathComponent("repositories.json") 
    }
    
    // MARK: - Initialization
    
    init(
        fileManager: FileManagerProtocol = FileManager.default,
        logger: LoggerProtocol = Logging.logger(for: .storage),
        securityService: SecurityServiceProtocol = SecurityService(),
        dateProvider: DateProviderProtocol = DateProvider(),
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default
    ) throws {
        self.fileManager = fileManager
        self.logger = logger
        self.securityService = securityService
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        
        // Set up storage in app container
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.storageDirectory = appSupport.appendingPathComponent("RepositoryStorage", isDirectory: true)
        
        try createStorageDirectoryIfNeeded()
        
        logger.debug("Initialized RepositoryStorage at: \(storageDirectory.path)", privacy: .public, file: #file, function: #function, line: #line)
    }
    
    // MARK: - StorageServiceProtocol Implementation
    
    func saveRepository(_ repository: Repository) async throws {
        logger.info("Saving repository: \(repository.name)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Validate repository path
            try securityService.validateAccess(to: repository.url)
            
            // Load existing repositories
            var repositories = try await loadRepositories()
            
            // Update or add repository
            if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
                repositories[index] = repository
            } else {
                repositories.append(repository)
            }
            
            // Save repositories
            try await saveRepositories(repositories)
            
            // Post notification
            notificationCenter.post(
                name: .repositoryUpdated,
                object: self,
                userInfo: ["repository": repository.id]
            )
            
            logger.info("Successfully saved repository", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to save repository: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    func loadRepositories() async throws -> [Repository] {
        logger.info("Loading repositories", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Check if storage file exists
            guard fileManager.fileExists(atPath: storageURL.path) else {
                logger.debug("No repositories file found, returning empty list", privacy: .public, file: #file, function: #function, line: #line)
                return []
            }
            
            // Load and decode repositories
            let data = try Data(contentsOf: storageURL)
            let repositories = try JSONDecoder().decode([Repository].self, from: data)
            
            // Validate repository paths
            for repository in repositories {
                try securityService.validateAccess(to: repository.url)
            }
            
            logger.info("Successfully loaded \(repositories.count) repositories", privacy: .public, file: #file, function: #function, line: #line)
            return repositories
        } catch {
            logger.error("Failed to load repositories: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    func deleteRepository(_ repository: Repository) async throws {
        logger.info("Deleting repository: \(repository.name)", privacy: .public, file: #file, function: #function, line: #line)
        
        do {
            // Load existing repositories
            var repositories = try await loadRepositories()
            
            // Remove repository
            repositories.removeAll { $0.id == repository.id }
            
            // Save updated repositories
            try await saveRepositories(repositories)
            
            // Post notification
            notificationCenter.post(
                name: .repositoryDeleted,
                object: self,
                userInfo: ["repository": repository.id]
            )
            
            logger.info("Successfully deleted repository", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to delete repository: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func createStorageDirectoryIfNeeded() throws {
        guard !fileManager.fileExists(atPath: storageDirectory.path) else { return }
        
        do {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            logger.debug("Created storage directory at: \(storageDirectory.path)", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to create storage directory: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
    
    private func saveRepositories(_ repositories: [Repository]) async throws {
        do {
            let data = try JSONEncoder().encode(repositories)
            try data.write(to: storageURL)
            logger.debug("Saved \(repositories.count) repositories to storage", privacy: .public, file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to save repositories: \(error.localizedDescription)", privacy: .public, file: #file, function: #function, line: #line)
            throw error
        }
    }
}
