@testable import Core
@testable import rBUM
import XCTest

// MARK: - Repository Test Utilities

extension XCTestCase {
    static func setupTestRepository() async throws -> TestRepository {
        let repository = try await createTestRepository()
        try await setupRepositoryStructure(for: repository)
        try await setupRepositoryData(for: repository)
        return repository
    }

    private static func createTestRepository() async throws -> TestRepository {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-repositories")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )

        return TestRepository(
            name: "Test Repository",
            location: baseURL,
            credentials: KeychainCredentials(
                identifier: UUID().uuidString,
                username: "test-user",
                password: "test-password"
            )
        )
    }

    private static func setupRepositoryStructure(for repository: TestRepository) async throws {
        let directories = [
            repository.location.appendingPathComponent("config"),
            repository.location.appendingPathComponent("data"),
            repository.location.appendingPathComponent("snapshots"),
            repository.location.appendingPathComponent("keys"),
            repository.location.appendingPathComponent("index")
        ]

        for directory in directories {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
    }

    private static func setupRepositoryData(for repository: TestRepository) async throws {
        let configData = """
        {
            "id": "\(UUID().uuidString)",
            "created": "\(ISO8601DateFormatter().string(from: Date()))",
            "version": 1,
            "compression": "auto",
            "chunker_polynomial": "0x3DA3358B4DC173"
        }
        """

        try configData.write(
            to: repository.location.appendingPathComponent("config/config"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func cleanupTestRepository(_ repository: TestRepository) throws {
        try cleanupRepositoryFiles(in: repository)
        try cleanupRepositoryDirectories(in: repository)
    }

    private static func cleanupRepositoryFiles(in repository: TestRepository) throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: repository.location,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let url = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
               !isDirectory.boolValue {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private static func cleanupRepositoryDirectories(in repository: TestRepository) throws {
        try FileManager.default.removeItem(at: repository.location)
    }
}
