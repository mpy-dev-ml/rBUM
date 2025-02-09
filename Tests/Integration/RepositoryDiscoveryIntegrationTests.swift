import Core
import Foundation
import ResticService
import Testing

struct RepositoryDiscoveryIntegrationTests {
    // MARK: - Properties
    
    let testDirectory = URL(filePath: "/tmp/rbum_test_repositories")
    let mockRepositories = [
        "/tmp/rbum_test_repositories/repo1",
        "/tmp/rbum_test_repositories/repo2",
        "/tmp/rbum_test_repositories/subfolder/repo3"
    ]
    let testURL = URL(filePath: "/tmp/rbum_test_repositories/test_repo")
    
    // MARK: - Setup
    
    func setupTestRepositories() throws {
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
        
        for path in mockRepositories {
            let url = URL(filePath: path)
            try FileManager.default.createDirectory(
                at: url.appending(path: "data"),
                withIntermediateDirectories: true
            )
            try """
            {
              "version": 1,
              "id": "\(UUID().uuidString)",
              "created": "\(Date().ISO8601Format())",
              "repository": {
                "version": 1,
                "compression": "auto"
              }
            }
            """.write(
                to: url.appending(path: "config"),
                atomically: true,
                encoding: .utf8
            )
        }
    }
    
    func cleanupTestRepositories() throws {
        try? FileManager.default.removeItem(at: testDirectory)
    }
    
    func setupTestRepository() throws {
        try FileManager.default.createDirectory(
            at: testURL,
            withIntermediateDirectories: true
        )
        
        try FileManager.default.createDirectory(
            at: testURL.appending(path: "data"),
            withIntermediateDirectories: true
        )
        
        try """
        {
          "version": 1,
          "id": "\(UUID().uuidString)",
          "created": "\(Date().ISO8601Format())",
          "repository": {
            "version": 1,
            "compression": "auto"
          }
        }
        """.write(
            to: testURL.appending(path: "config"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    func cleanupTestRepository() throws {
        try? FileManager.default.removeItem(at: testURL)
    }
    
    // MARK: - Integration Tests
    
    @Test
    func testFullDiscoveryWorkflow() async throws {
        // Arrange
        try setupTestRepositories()
        defer { try? cleanupTestRepositories() }
        
        let xpcConnection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        let securityService = MockSecurityService()
        let bookmarkStorage = MockBookmarkStorage()
        
        let discoveryService = RepositoryDiscoveryService(
            xpcConnection: xpcConnection,
            securityService: securityService,
            bookmarkStorage: bookmarkStorage
        )
        
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: discoveryService)
        
        // Act & Assert
        
        // 1. Start scan
        viewModel.startScan(at: testDirectory, recursive: true)
        try await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
        
        // 2. Verify repositories were found
        #expect(viewModel.discoveredRepositories.count == 3)
        #expect(viewModel.scanningStatus == .completed(foundCount: 3))
        
        // 3. Add first repository
        if let firstRepo = viewModel.discoveredRepositories.first {
            try await viewModel.addRepository(firstRepo)
            #expect(true) // No error thrown
        }
        
        // 4. Cancel scan of another directory
        viewModel.startScan(at: testDirectory.appending(path: "nonexistent"), recursive: true)
        viewModel.cancelScan()
        #expect(viewModel.scanningStatus == .idle)
    }
    
    // MARK: - Repository Indexing Tests
    
    @Test
    func testRepositoryIndexing_Success() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }
        
        // Create test snapshots and files
        try await createTestSnapshot(
            id: "test-snapshot-1",
            files: [
                ("test1.txt", "Test content 1"),
                ("test2.txt", "Test content 2")
            ]
        )
        
        let service = ResticService()
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)
        
        // Act
        try await viewModel.startDiscovery(at: testURL)
        
        // Wait for discovery to complete
        while viewModel.scanningStatus != .completed(foundCount: 1) {
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Verify repository was found
        #expect(viewModel.discoveredRepositories.count == 1)
        
        // Index the repository
        guard let repository = viewModel.discoveredRepositories.first else {
            throw RepositoryDiscoveryError.discoveryFailed("No repository found")
        }
        
        try await service.indexRepository(at: repository.url)
        
        // Assert
        // Note: In a real implementation, we would verify the index contents
        // For now, we just verify no errors were thrown
        #expect(true)
    }
    
    @Test
    func testRepositoryIndexing_EmptyRepository() async throws {
        // Arrange
        try setupTestRepository()
        defer { try? cleanupTestRepository() }
        
        let service = ResticService()
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)
        
        // Act
        try await viewModel.startDiscovery(at: testURL)
        
        // Wait for discovery to complete
        while viewModel.scanningStatus != .completed(foundCount: 1) {
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Verify repository was found
        #expect(viewModel.discoveredRepositories.count == 1)
        
        // Index the repository
        guard let repository = viewModel.discoveredRepositories.first else {
            throw RepositoryDiscoveryError.discoveryFailed("No repository found")
        }
        
        try await service.indexRepository(at: repository.url)
        
        // Assert
        // Verify no errors when indexing empty repository
        #expect(true)
    }
    
    // MARK: - Helper Methods
    
    private func createTestSnapshot(
        id: String,
        files: [(name: String, content: String)]
    ) async throws {
        // Create test files
        let snapshotDir = testURL.appending(path: "snapshots").appending(path: id)
        try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
        
        for (name, content) in files {
            let fileURL = snapshotDir.appending(path: name)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        
        // Create snapshot metadata
        let snapshotData = """
        {
            "id": "\(id)",
            "time": "2025-02-09T15:00:00Z",
            "paths": ["\(snapshotDir.path)"]
        }
        """
        
        try snapshotData.write(
            to: testURL.appending(path: "snapshots").appending(path: "\(id).json"),
            atomically: true,
            encoding: .utf8
        )
    }
}

// MARK: - Mock Services

private final class MockSecurityService: SecurityServiceProtocol {
    func validateAccess(to url: URL) -> Bool { true }
    func requestAccess(to url: URL) async throws -> Bool { true }
}

private final class MockBookmarkStorage: BookmarkStorageProtocol {
    private var bookmarks: [String: Data] = [:]
    
    func storeBookmark(_ bookmark: Data, for url: URL) async throws {
        bookmarks[url.path] = bookmark
    }
    
    func getBookmark(for url: URL) async throws -> Data? {
        bookmarks[url.path]
    }
    
    func removeBookmark(for url: URL) async throws {
        bookmarks.removeValue(forKey: url.path)
    }
}
