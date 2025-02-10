import Core
import Foundation
import XCTest

extension DefaultSecurityServiceTests {
    /// Helper to create a test repository URL
    func createTestRepositoryURL(name: String) throws -> URL {
        let baseURL = try URL.temporaryTestDirectory(name: "test-repositories")
        return baseURL.appendingPathComponent(name)
    }

    /// Helper to create a test repository with credentials
    func createTestRepository(name: String) throws -> Repository {
        let url = try createTestRepositoryURL(name: name)
        let id = UUID()
        let repository = Repository(id: id, url: url)

        // Create test credentials
        let credentials = RepositoryCredentials(
            username: "test-user",
            password: "test-password"
        )
        try mockKeychainService.store(
            credentials,
            forId: id.uuidString
        )

        return repository
    }

    /// Helper to validate repository access
    func validateRepositoryAccess(_ repository: Repository) async throws -> Bool {
        try await service.validateRepositoryAccess(repository.url)
    }

    /// Helper to clean up test URLs
    func cleanupTestURLs(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
