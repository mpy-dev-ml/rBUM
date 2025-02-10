import XCTest
@testable import Core
@testable import rBUM

extension DefaultSecurityServiceTests {
    // MARK: - Test Setup Helpers

    func setupTestEnvironment() throws {
        try setupTestDirectories()
        try setupTestFiles()
        setupMockServices()
    }

    private func setupTestDirectories() throws {
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }

        // Create test subdirectories
        let sourceDirectory = testURL.appendingPathComponent("source")
        let destinationDirectory = testURL.appendingPathComponent("destination")

        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    }

    private func setupTestFiles() throws {
        // Create test files with different permissions
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }

        try createTestFile(named: "readable.txt", permissions: [.readable], at: testURL)
        try createTestFile(named: "writable.txt", permissions: [.writable], at: testURL)
        try createTestFile(named: "executable.txt", permissions: [.executable], at: testURL)
        try createTestFile(named: "full-access.txt", permissions: [.readable, .writable, .executable], at: testURL)
    }

    private func setupMockServices() {
        mockBookmarkService = MockBookmarkService()
        mockKeychainService = MockKeychainService()
        mockLogger = MockLogger()

        configureBookmarkServiceMock()
        configureKeychainMock()
    }

    private func createTestFile(named name: String, permissions: Set<FilePermission>, at url: URL) throws {
        let filePath = url.appendingPathComponent(name)
        try "Test content".write(to: filePath, atomically: true, encoding: .utf8)

        // Set file permissions
        var attributes: [FileAttributeKey: Any] = [:]
        if permissions.contains(.readable) {
            attributes[.posixPermissions] = 0o444
        }
        if permissions.contains(.writable) {
            attributes[.posixPermissions] = 0o222
        }
        if permissions.contains(.executable) {
            attributes[.posixPermissions] = 0o111
        }
        try fileManager.setAttributes(attributes, ofItemAtPath: filePath.path)
    }

    private func createSecurityScopedURL(for url: URL) throws -> URL {
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var isStale = false
        let securityScopedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return securityScopedURL
    }

    private func configureBookmarkServiceMock() {
        mockBookmarkService.createBookmarkHandler = { url in
            try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        mockBookmarkService.resolveBookmarkHandler = { data in
            var isStale = false
            return try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
    }

    private func configureKeychainMock() {
        mockKeychainService.saveHandler = { _, _, _ in
            // Simulate successful keychain save
            true
        }

        mockKeychainService.loadHandler = { _, _ in
            // Return test data
            Data("test-data".utf8)
        }
    }

    // MARK: - Verification Helpers

    func verifySecurityAccess(for url: URL) throws {
        let hasAccess = try service.validateAccess(to: url)
        XCTAssertTrue(hasAccess, "Should have access to \(url.path)")

        let operations = service.getOperations(for: url)
        XCTAssertFalse(operations.isEmpty, "Should have recorded security operations")

        let lastOperation = operations.last
        XCTAssertEqual(lastOperation?.status, .success, "Last operation should be successful")
    }

    func verifySecurityDenied(for url: URL) throws {
        let hasAccess = try service.validateAccess(to: url)
        XCTAssertFalse(hasAccess, "Should not have access to \(url.path)")

        let operations = service.getOperations(for: url)
        XCTAssertFalse(operations.isEmpty, "Should have recorded security operations")

        let lastOperation = operations.last
        XCTAssertEqual(lastOperation?.status, .failure, "Last operation should be failure")
    }

    func verifyBookmarkCreation(for url: URL) throws {
        let bookmark = try service.createBookmark(for: url)
        XCTAssertNotNil(bookmark, "Should create bookmark")

        let operations = service.getOperations(for: url)
        let bookmarkOperations = operations.filter { $0.type == .createBookmark }
        XCTAssertFalse(bookmarkOperations.isEmpty, "Should have recorded bookmark creation")
    }
}
