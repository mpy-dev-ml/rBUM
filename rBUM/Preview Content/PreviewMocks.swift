import Core
import Foundation

/// Mock objects for SwiftUI previews
enum PreviewMocks {
    static let credentialsManager: KeychainCredentialsManagerProtocol = MockCredentialsManager()
    static let repositoryStorage: RepositoryStorageProtocol = MockRepositoryStorage()
    static let resticService: ResticCommandServiceProtocol = MockResticService()
    static let repositoryCreationService: RepositoryCreationServiceProtocol = MockRepositoryCreationService()
    static let fileSearchService: FileSearchServiceProtocol = MockFileSearchService()
    static let restoreService: RestoreServiceProtocol = MockRestoreService()
}

// MARK: - Mock Implementations

private class MockCredentialsManager: KeychainCredentialsManagerProtocol {
    func storeCredentials(_ credentials: RepositoryCredentials, for repository: Repository) async throws {}
    func retrieveCredentials(for repository: Repository) async throws -> RepositoryCredentials? { nil }
    func deleteCredentials(for repository: Repository) async throws {}
}

private class MockRepositoryStorage: RepositoryStorageProtocol {
    func loadRepositories() async throws -> [Repository] { [] }
    func saveRepository(_ repository: Repository) async throws {}
    func deleteRepository(_ repository: Repository) async throws {}
}

private class MockResticService: ResticCommandServiceProtocol {
    func initRepository(_ repository: Repository) async throws {}
    func createBackup(in repository: Repository, paths: [String]) async throws {}
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] { [] }
    func performHealthCheck() async throws -> Bool { true }
}

private class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(at url: URL, with credentials: RepositoryCredentials) async throws -> Repository {
        Repository(url: url)
    }
}

private class MockFileSearchService: FileSearchServiceProtocol {
    func searchFile(pattern: String, in repository: Repository) async throws -> [FileMatch] {
        []
    }

    func getFileVersions(path: String, in repository: Repository) async throws -> [FileVersion] {
        []
    }
}

private class MockRestoreService: RestoreServiceProtocol {
    func restore(
        snapshot: ResticSnapshot,
        from repository: Repository,
        paths: [String],
        to target: String
    ) async throws {}

    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        []
    }
}
