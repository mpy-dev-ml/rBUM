import XCTest
@testable import Core
@testable import rBUM

extension XCTestCase {
    static func setupTestRepository() async throws -> TestRepository {
        let repository = try await createTestRepository()
        try await setupRepositoryStructure(for: repository)
        try await setupRepositoryData(for: repository)
        return repository
    }

    static func cleanupTestRepository(_ repository: TestRepository) throws {
        try cleanupRepositoryFiles(in: repository)
        try cleanupRepositoryDirectories(in: repository)
    }

    private static func createTestRepository() async throws -> TestRepository {
        // Implementation moved from TestUtilities.swift
    }

    private static func setupRepositoryStructure(for repository: TestRepository) async throws {
        // Implementation moved from TestUtilities.swift
    }

    private static func setupRepositoryData(for repository: TestRepository) async throws {
        // Implementation moved from TestUtilities.swift
    }

    private static func cleanupRepositoryFiles(in repository: TestRepository) throws {
        // Implementation moved from TestUtilities.swift
    }

    private static func cleanupRepositoryDirectories(in repository: TestRepository) throws {
        // Implementation moved from TestUtilities.swift
    }
}
