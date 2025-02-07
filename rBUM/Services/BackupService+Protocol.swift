import Core
import Foundation

// MARK: - BackupServiceProtocol Implementation

extension BackupService {
    public func initializeRepository(_ repository: Repository) async throws {
        try await resticService.initializeRepository(repository)
    }
    
    public func createBackup(
        to repository: Repository,
        paths: [String],
        tags: [String]
    ) async throws {
        let id = UUID()
        await backupState.insert(id)
        defer { Task { await backupState.remove(id) } }
        
        // Record operation start
        let operation = BackupOperation(
            id: id,
            source: URL(fileURLWithPath: paths.first ?? ""),
            destination: repository.url,
            excludes: [],
            tags: tags,
            startTime: Date()
        )
        
        do {
            try await resticService.createBackup(
                repository: repository,
                paths: paths,
                tags: tags
            )
        } catch {
            throw BackupError.executionFailed(error)
        }
    }
    
    public func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        try await resticService.listSnapshots(in: repository)
    }
    
    public func restoreSnapshot(
        _ snapshot: ResticSnapshot,
        from repository: Repository,
        to destination: String
    ) async throws {
        try await resticService.restoreSnapshot(
            snapshot,
            from: repository,
            to: destination
        )
    }
    
    public func deleteSnapshot(
        _ snapshot: ResticSnapshot,
        from repository: Repository
    ) async throws {
        try await resticService.deleteSnapshot(
            snapshot,
            from: repository
        )
    }
    
    public func verifyRepository(_ repository: Repository) async throws {
        try await resticService.verifyRepository(repository)
    }
    
    public func pruneRepository(_ repository: Repository) async throws {
        try await resticService.pruneRepository(repository)
    }
}
