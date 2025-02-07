//
//  TestRepositoryHelpers.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

@testable import Core
@testable import rBUM
import XCTest

// MARK: - Test Repository Setup

extension XCTestCase {
    static func setupTestRepository() async throws -> TestRepository {
        let repository = try await createTestRepository()
        try await setupRepositoryStructure(for: repository)
        try await setupRepositoryData(for: repository)
        return repository
    }

    private static func createTestRepository() async throws -> TestRepository {
        let fileManager = FileManager.default
        let testDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        return TestRepository(
            fileManager: fileManager,
            rootDirectory: testDirectory,
            configDirectory: testDirectory.appendingPathComponent("config"),
            dataDirectory: testDirectory.appendingPathComponent("data"),
            metadataDirectory: testDirectory.appendingPathComponent("metadata"),
            tempDirectory: testDirectory.appendingPathComponent("temp")
        )
    }

    private static func setupRepositoryStructure(for repository: TestRepository) async throws {
        // Create main repository directory
        try repository.fileManager.createDirectory(
            at: repository.rootDirectory,
            withIntermediateDirectories: true
        )

        // Create subdirectories
        try repository.fileManager.createDirectory(
            at: repository.configDirectory,
            withIntermediateDirectories: true
        )

        try repository.fileManager.createDirectory(
            at: repository.dataDirectory,
            withIntermediateDirectories: true
        )

        try repository.fileManager.createDirectory(
            at: repository.metadataDirectory,
            withIntermediateDirectories: true
        )

        try repository.fileManager.createDirectory(
            at: repository.tempDirectory,
            withIntermediateDirectories: true
        )
    }

    private static func setupRepositoryData(for repository: TestRepository) async throws {
        // Create test config file
        try createTestConfigFile(in: repository)

        // Create test data files
        try createTestDataFiles(in: repository)

        // Create test metadata files
        try createTestMetadataFiles(in: repository)
    }

    private static func createTestConfigFile(in repository: TestRepository) throws {
        let config = TestRepositoryConfig(
            version: "1.0.0",
            created: Date(),
            lastModified: Date(),
            settings: TestRepositorySettings(
                compression: true,
                encryption: true,
                deduplication: true
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let configData = try encoder.encode(config)

        let configFile = repository.configDirectory.appendingPathComponent("config.json")
        try configData.write(to: configFile)
    }

    private static func createTestDataFiles(in repository: TestRepository) throws {
        // Create small test file
        try generateTestFile(
            name: "small.dat",
            size: 1024
        ).write(to: repository.dataDirectory.appendingPathComponent("small.dat"))

        // Create medium test file
        try generateTestFile(
            name: "medium.dat",
            size: 1024 * 1024
        ).write(to: repository.dataDirectory.appendingPathComponent("medium.dat"))

        // Create large test file
        try generateTestFile(
            name: "large.dat",
            size: 1024 * 1024 * 10
        ).write(to: repository.dataDirectory.appendingPathComponent("large.dat"))
    }

    private static func createTestMetadataFiles(in repository: TestRepository) throws {
        // Create index file
        let index = TestRepositoryIndex(
            files: [
                "small.dat": TestFileMetadata(size: 1024, chunks: 1),
                "medium.dat": TestFileMetadata(size: 1024 * 1024, chunks: 10),
                "large.dat": TestFileMetadata(size: 1024 * 1024 * 10, chunks: 100)
            ]
        )

        let encoder = JSONEncoder()
        let indexData = try encoder.encode(index)

        let indexFile = repository.metadataDirectory.appendingPathComponent("index.json")
        try indexData.write(to: indexFile)

        // Create snapshot file
        let snapshot = TestRepositorySnapshot(
            id: UUID(),
            timestamp: Date(),
            files: [
                "small.dat",
                "medium.dat",
                "large.dat"
            ]
        )

        let snapshotData = try encoder.encode(snapshot)
        let snapshotFile = repository.metadataDirectory.appendingPathComponent("snapshot.json")
        try snapshotData.write(to: snapshotFile)
    }
}

// MARK: - Test Repository Cleanup

extension XCTestCase {
    static func cleanupTestRepository(_ repository: TestRepository) throws {
        try cleanupRepositoryFiles(in: repository)
        try cleanupRepositoryDirectories(in: repository)
    }

    private static func cleanupRepositoryFiles(in repository: TestRepository) throws {
        // Clean up config files
        let configFiles = try repository.fileManager.contentsOfDirectory(
            at: repository.configDirectory,
            includingPropertiesForKeys: nil
        )
        for file in configFiles {
            try repository.fileManager.removeItem(at: file)
        }

        // Clean up data files
        let dataFiles = try repository.fileManager.contentsOfDirectory(
            at: repository.dataDirectory,
            includingPropertiesForKeys: nil
        )
        for file in dataFiles {
            try repository.fileManager.removeItem(at: file)
        }

        // Clean up metadata files
        let metadataFiles = try repository.fileManager.contentsOfDirectory(
            at: repository.metadataDirectory,
            includingPropertiesForKeys: nil
        )
        for file in metadataFiles {
            try repository.fileManager.removeItem(at: file)
        }
    }

    private static func cleanupRepositoryDirectories(in repository: TestRepository) throws {
        try repository.fileManager.removeItem(at: repository.configDirectory)
        try repository.fileManager.removeItem(at: repository.dataDirectory)
        try repository.fileManager.removeItem(at: repository.metadataDirectory)
        try repository.fileManager.removeItem(at: repository.tempDirectory)
        try repository.fileManager.removeItem(at: repository.rootDirectory)
    }
}
