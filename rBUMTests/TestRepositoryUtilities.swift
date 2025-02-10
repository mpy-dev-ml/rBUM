import XCTest
@testable import Core
@testable import rBUM

extension XCTestCase {
    /// Sets up a test repository
    /// - Returns: The set up test repository
    /// - Throws: Error if setup fails
    static func setupTestRepository() async throws -> TestRepository {
        let repository = try await TestRepository()
        try createTestMetadataFiles(in: repository)
        return repository
    }

    /// Creates test metadata files in the repository
    /// - Parameter repository: The repository to create files in
    /// - Throws: Error if file creation fails
    private static func createTestMetadataFiles(in repository: TestRepository) throws {
        // Create index file
        let index = TestRepositoryIndex(
            files: [
                "small.dat": TestFileMetadata(size: 1024, chunks: 1),
                "medium.dat": TestFileMetadata(size: 1024 * 1024, chunks: 10),
                "large.dat": TestFileMetadata(size: 1024 * 1024 * 10, chunks: 100),
            ]
        )

        try repository.writeIndex(index)

        // Create test files
        try repository.createTestFiles()
    }
}

// MARK: - Test Repository Cleanup

extension XCTestCase {
    /// Cleans up a test repository
    /// - Parameter repository: The repository to clean up
    func cleanupTestRepository(_ repository: TestRepository) throws {
        try repository.cleanup()
    }

    /// Cleans up all test repositories
    func cleanupAllTestRepositories() throws {
        let testDir = try XCTUnwrap(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let repoDir = testDir.appendingPathComponent("TestRepositories")
        try? FileManager.default.removeItem(at: repoDir)
    }
}
