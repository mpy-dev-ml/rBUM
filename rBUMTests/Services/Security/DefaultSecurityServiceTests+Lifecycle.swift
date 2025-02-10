import Core
import XCTest

extension DefaultSecurityServiceTests {
    func testServiceInitialization() {
        XCTAssertNotNil(service)
        XCTAssertNotNil(mockKeychainService)
        XCTAssertNotNil(mockBookmarkService)
    }

    func testServiceShutdown() async throws {
        // Create test repository
        let repository = try createTestRepository(name: "test-repo")

        // Start accessing resources
        try await service.startAccessing(repository.url)

        // Verify access is granted
        await XCTAssertTrue(try validateRepositoryAccess(repository))

        // Shutdown service
        try await service.shutdown()

        // Verify access is revoked
        await XCTAssertFalse(try validateRepositoryAccess(repository))

        // Clean up
        cleanupTestURLs(repository.url)
    }

    func testServiceReset() async throws {
        // Create test repositories
        let repo1 = try createTestRepository(name: "test-repo-1")
        let repo2 = try createTestRepository(name: "test-repo-2")

        // Start accessing resources
        try await service.startAccessing(repo1.url)
        try await service.startAccessing(repo2.url)

        // Verify access is granted
        await XCTAssertTrue(try validateRepositoryAccess(repo1))
        await XCTAssertTrue(try validateRepositoryAccess(repo2))

        // Reset service
        try await service.reset()

        // Verify access is revoked
        await XCTAssertFalse(try validateRepositoryAccess(repo1))
        await XCTAssertFalse(try validateRepositoryAccess(repo2))

        // Clean up
        cleanupTestURLs(repo1.url, repo2.url)
    }
}
