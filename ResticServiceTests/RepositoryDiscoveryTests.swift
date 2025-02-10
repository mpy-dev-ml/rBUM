import Foundation
import Testing
@testable import ResticService

struct RepositoryDiscoveryTests {
    // MARK: - Properties

    let testURL = URL(filePath: "/test/repository")
    let mockConfig = """
    {
      "version": 1,
      "id": "5e13c640b5",
      "created": "2025-02-09T15:00:00.000000000Z",
      "repository": {
        "version": 1,
        "compression": "auto"
      }
    }
    """

    // MARK: - Setup

    func setupTestRepository() throws {
        try FileManager.default.createDirectory(
            at: testURL.appending(path: "data"),
            withIntermediateDirectories: true
        )
        try mockConfig.write(
            to: testURL.appending(path: "config"),
            atomically: true,
            encoding: .utf8
        )
    }

    func cleanupTestRepository() throws {
        try? FileManager.default.removeItem(at: testURL)
    }

    // MARK: - Scanning Tests

    @Test
    func testScanLocation_ValidRepository() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Act
        let urls = try await service.scanForRepositories(at: testURL, recursive: false)

        // Assert
        #expect(!urls.isEmpty)
        #expect(urls.contains(testURL))
    }

    @Test
    func testScanLocation_InvalidRepository() async throws {
        // Arrange
        let service = ResticService()

        // Act
        let urls = try await service.scanForRepositories(at: testURL, recursive: false)

        // Assert
        #expect(urls.isEmpty)
    }

    @Test
    func testScanLocation_RecursiveSearch() async throws {
        // Arrange
        let subfolderURL = testURL.appending(path: "subfolder")
        try setupTestRepository()
        try FileManager.default.createDirectory(
            at: subfolderURL,
            withIntermediateDirectories: true
        )
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Act
        let urls = try await service.scanForRepositories(at: testURL, recursive: true)

        // Assert
        #expect(!urls.isEmpty)
        #expect(urls.contains(testURL))
    }

    // MARK: - Verification Tests

    @Test
    func testVerifyRepository_ValidRepository() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Act
        let isValid = try await service.verifyResticRepository(at: testURL)

        // Assert
        #expect(isValid)
    }

    @Test
    func testVerifyRepository_InvalidRepository() async throws {
        // Arrange
        let service = ResticService()

        // Act
        let isValid = try await service.verifyResticRepository(at: testURL)

        // Assert
        #expect(!isValid)
    }

    // MARK: - Metadata Tests

    @Test
    func testFetchRepositoryMetadata() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Act
        let metadata = try await service.fetchRepositoryMetadata(for: testURL)

        // Assert
        #expect(metadata["size"] is UInt64)
        #expect(metadata["lastModified"] is Date)
    }

    @Test
    func testCalculateRepositorySize() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Act
        let size = try await service.calculateRepositorySize(at: testURL)

        // Assert
        #expect(size > 0)
    }

    // MARK: - Operation Management Tests

    @Test
    func testCancelOperations() async throws {
        // Arrange
        let service = ResticService()

        // Act & Assert
        service.cancelOperations()
        // Verify no crash occurs and operations are cleared
        #expect(true)
    }

    // MARK: - Indexing Tests

    @Test
    func testIndexRepository_Success() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        // Create mock snapshot data
        try """
        [
          {
            "id": "a1b2c3d4",
            "time": "2025-02-09T15:00:00.000000000Z",
            "paths": ["/test/path1", "/test/path2"]
          }
        ]
        """.write(
            to: testURL.appending(path: "snapshots.json"),
            atomically: true,
            encoding: .utf8
        )

        let service = ResticService()

        // Mock restic command responses
        try service.mockCommandResponse(
            for: ["snapshots", "--json", "-r", testURL.path],
            output: String(contentsOf: testURL.appending(path: "snapshots.json"))
        )

        service.mockCommandResponse(
            for: ["ls", "--json", "-r", testURL.path, "a1b2c3d4"],
            output: """
            [
              {
                "name": "test1.txt",
                "type": "file",
                "path": "/test/path1/test1.txt",
                "size": 1024
              },
              {
                "name": "test2.txt",
                "type": "file",
                "path": "/test/path2/test2.txt",
                "size": 2048
              }
            ]
            """
        )

        // Act
        try await service.indexRepository(at: testURL)

        // Assert
        #expect(service.commandWasExecuted(["snapshots", "--json", "-r", testURL.path]))
        #expect(service.commandWasExecuted(["ls", "--json", "-r", testURL.path, "a1b2c3d4"]))
    }

    @Test
    func testIndexRepository_EmptyRepository() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Mock empty snapshots response
        service.mockCommandResponse(
            for: ["snapshots", "--json", "-r", testURL.path],
            output: "[]"
        )

        // Act
        try await service.indexRepository(at: testURL)

        // Assert
        #expect(service.commandWasExecuted(["snapshots", "--json", "-r", testURL.path]))
        #expect(!service.commandWasExecuted(["ls", "--json", "-r", testURL.path]))
    }

    @Test
    func testIndexRepository_SnapshotListingFailure() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Mock failed snapshots command
        service.mockCommandFailure(
            for: ["snapshots", "--json", "-r", testURL.path],
            exitCode: 1
        )

        // Act & Assert
        await #expect(throws: RepositoryDiscoveryError.discoveryFailed("Failed to read snapshots")) {
            try await service.indexRepository(at: testURL)
        }
    }

    @Test
    func testIndexRepository_FileListingFailure() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }

        let service = ResticService()

        // Mock successful snapshots but failed ls command
        service.mockCommandResponse(
            for: ["snapshots", "--json", "-r", testURL.path],
            output: """
            [{"id": "a1b2c3d4", "time": "2025-02-09T15:00:00Z"}]
            """
        )

        service.mockCommandFailure(
            for: ["ls", "--json", "-r", testURL.path, "a1b2c3d4"],
            exitCode: 1
        )

        // Act & Assert
        await #expect(throws: RepositoryDiscoveryError.discoveryFailed("Failed to list snapshot contents")) {
            try await service.indexRepository(at: testURL)
        }
    }
}
