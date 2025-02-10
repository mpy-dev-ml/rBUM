import XCTest
@testable import Core
@testable import rBUM

struct TestRepository {
    let url: URL
    let password: String
    let name: String

    init(url: URL, password: String = "test-password", name: String = "test-repo") {
        self.url = url
        self.password = password
        self.name = name
    }
}

extension XCTestCase {
    static func setupTestRepository() async throws -> TestRepository {
        let repository = try await createTestRepository()
        try await setupRepositoryStructure(for: repository)
        try await setupRepositoryData(for: repository)
        return repository
    }

    static func createTestRepository() async throws -> TestRepository {
        let tempDir = FileManager.default.temporaryDirectory
        let repoURL = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        return TestRepository(url: repoURL)
    }

    static func setupRepositoryStructure(for repository: TestRepository) async throws {
        let directories = [
            "config",
            "data",
            "keys",
            "snapshots",
            "index",
        ]

        for directory in directories {
            let dirURL = repository.url.appendingPathComponent(directory)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
    }

    static func setupRepositoryData(for repository: TestRepository) async throws {
        // Add test data files
        let dataFiles = [
            "config/config.yml": "repository: \(repository.name)\npassword: \(repository.password)",
            "data/test.dat": "test data",
            "keys/master.key": "test key",
            "snapshots/latest.json": "{ \"id\": \"test\" }",
            "index/index.db": "test index",
        ]

        for (path, content) in dataFiles {
            let fileURL = repository.url.appendingPathComponent(path)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    static func cleanupTestRepository(_ repository: TestRepository) throws {
        try cleanupRepositoryFiles(in: repository)
        try cleanupRepositoryDirectories(in: repository)
    }

    private static func cleanupRepositoryFiles(in repository: TestRepository) throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(at: repository.url, includingPropertiesForKeys: [.isRegularFileKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }

    private static func cleanupRepositoryDirectories(in repository: TestRepository) throws {
        try FileManager.default.removeItem(at: repository.url)
    }
}
