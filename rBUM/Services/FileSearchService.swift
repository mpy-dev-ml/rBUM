import Core
import Foundation

/// Service for searching files across backups
@globalActor actor FileSearchActor {
    static let shared = FileSearchActor()
}

/// Implementation of file search service
@FileSearchActor
final class FileSearchService: BaseSandboxedService, FileSearchServiceProtocol, HealthCheckable {
    // MARK: - Properties
    
    private let resticService: ResticServiceProtocol
    private let repositoryLock: RepositoryLockProtocol
    private let logger: LoggerProtocol
    private var _isHealthy: Bool = true
    
    @objc public var isHealthy: Bool { _isHealthy }
    
    // MARK: - Initialisation
    
    /// Initialise a new FileSearchService
    /// - Parameters:
    ///   - resticService: Service for interacting with restic
    ///   - repositoryLock: Lock manager for repository access
    ///   - logger: Logger instance
    public init(
        resticService: ResticServiceProtocol,
        repositoryLock: RepositoryLockProtocol,
        logger: LoggerProtocol
    ) {
        self.resticService = resticService
        self.repositoryLock = repositoryLock
        self.logger = logger
    }
    
    // MARK: - Health Check
    
    public func updateHealthStatus() async {
        _isHealthy = await (try? resticService.performHealthCheck()) ?? false
    }
    
    // MARK: - FileSearchServiceProtocol Implementation
    
    public func searchFile(
        pattern: String,
        in repository: Repository
    ) async throws -> [FileMatch] {
        logger.debug("Searching for files matching pattern: \(pattern)", privacy: .public)
        
        // Validate pattern
        guard isValidPattern(pattern) else {
            throw FileSearchError.invalidPattern(pattern)
        }
        
        // Acquire repository lock
        guard await repositoryLock.acquireLock(for: repository) else {
            throw FileSearchError.repositoryLocked
        }
        defer { Task { await repositoryLock.releaseLock(for: repository) } }
        
        do {
            // Get all snapshots
            let snapshots = try await resticService.listSnapshots(in: repository)
            
            // Search in each snapshot
            var matches: [FileMatch] = []
            for snapshot in snapshots {
                let files = try await resticService.findFiles(
                    matching: pattern,
                    in: snapshot,
                    repository: repository
                )
                
                // Convert to FileMatch objects
                let snapshotMatches = files.map { file in
                    FileMatch(
                        path: file.path,
                        size: file.size,
                        modTime: file.modTime,
                        snapshot: snapshot
                    )
                }
                
                matches.append(contentsOf: snapshotMatches)
            }
            
            logger.info("Found \(matches.count) matches for pattern: \(pattern)", privacy: .public)
            return matches
            
        } catch {
            logger.error("File search failed: \(error.localizedDescription)", privacy: .public)
            throw FileSearchError.searchFailed(error.localizedDescription)
        }
    }
    
    public func getFileVersions(
        path: String,
        in repository: Repository
    ) async throws -> [FileVersion] {
        logger.debug("Getting versions for file: \(path)", privacy: .public)
        
        // Acquire repository lock
        guard await repositoryLock.acquireLock(for: repository) else {
            throw FileSearchError.repositoryLocked
        }
        defer { Task { await repositoryLock.releaseLock(for: repository) } }
        
        do {
            // Get all snapshots
            let snapshots = try await resticService.listSnapshots(in: repository)
            
            // Find file in each snapshot
            var versions: [FileVersion] = []
            for snapshot in snapshots {
                if let file = try await resticService.findFile(
                    path: path,
                    in: snapshot,
                    repository: repository
                ) {
                    let version = FileVersion(
                        path: file.path,
                        size: file.size,
                        modTime: file.modTime,
                        snapshot: snapshot,
                        hash: file.hash
                    )
                    versions.append(version)
                }
            }
            
            logger.info("Found \(versions.count) versions for file: \(path)", privacy: .public)
            return versions
            
        } catch {
            logger.error("Getting file versions failed: \(error.localizedDescription)", privacy: .public)
            throw FileSearchError.searchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helpers
    
    private func isValidPattern(_ pattern: String) -> Bool {
        // Pattern validation rules:
        // 1. Must not be empty
        // 2. Must be at least 3 characters
        // 3. Must not contain invalid characters
        // 4. Must not be too complex
        
        guard !pattern.isEmpty, pattern.count >= 3 else {
            return false
        }
        
        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "\\:*?\"<>|")
        guard pattern.rangeOfCharacter(from: invalidCharacters) == nil else {
            return false
        }
        
        // Check pattern complexity
        let complexityIndicators = ["**", "??", "[]", "{}", "()"]
        let hasComplexPatterns = complexityIndicators.contains { pattern.contains($0) }
        
        // Allow only simple glob patterns
        return !hasComplexPatterns
    }
}
