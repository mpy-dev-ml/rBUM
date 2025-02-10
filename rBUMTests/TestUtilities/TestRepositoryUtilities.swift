import XCTest
@testable import Core
@testable import rBUM

// MARK: - Test Repository

struct TestRepository {
    let url: URL
    let credentials: RepositoryCredentials
    let files: [URL]
}

// MARK: - Repository Setup

extension XCTestCase {
    static func setupTestRepository() async throws -> TestRepository {
        let repository = try await createTestRepository()
        try await setupRepositoryStructure(for: repository)
        try await setupRepositoryData(for: repository)
        return repository
    }

    private static func createTestRepository() async throws -> TestRepository {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestRepository")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )

        let credentials = RepositoryCredentials(
            url: baseURL,
            password: "test-password",
            type: .local
        )

        return TestRepository(
            url: baseURL,
            credentials: credentials,
            files: []
        )
    }

    static func cleanupTestRepository(_ repository: TestRepository) throws {
        try FileManager.default.removeItem(at: repository.url)
    }
}
