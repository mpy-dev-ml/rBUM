import XCTest
@testable import Core
@testable import rBUM

/// Extension containing test setup and environment configuration methods for DefaultSecurityServiceTests
extension DefaultSecurityServiceTests {
    // MARK: - Test Setup Helpers

    /// Sets up the test environment by configuring directories, files, and mock services
    /// - Throws: If there is an error setting up the test environment
    func setupTestEnvironment() throws {
        try setupTestDirectories()
        try setupTestFiles()
        setupMockServices()
    }

    /// Sets up test directories for the test environment
    /// - Throws: If there is an error creating the directories
    func setupTestDirectories() throws {
        let testURL = try URL.temporaryTestDirectory(name: "test-access")
        defer { cleanupTestURLs(testURL) }

        // Create test subdirectories
        let sourceDirectory = testURL.appendingPathComponent("source")
        let destinationDirectory = testURL.appendingPathComponent("destination")

        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    }

    /// Sets up test files with various permissions and content
    /// - Throws: If there is an error creating or configuring the test files
    func setupTestFiles() throws {
        let testURL = try URL.temporaryTestDirectory(name: "test-files")
        defer { cleanupTestURLs(testURL) }

        // Create test files with different permissions
        let readableFile = testURL.appendingPathComponent("readable.txt")
        let writableFile = testURL.appendingPathComponent("writable.txt")
        let executableFile = testURL.appendingPathComponent("executable.txt")

        try "Test content".write(to: readableFile, atomically: true, encoding: .utf8)
        try "Test content".write(to: writableFile, atomically: true, encoding: .utf8)
        try "Test content".write(to: executableFile, atomically: true, encoding: .utf8)

        try fileManager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: readableFile.path)
        try fileManager.setAttributes([.posixPermissions: 0o666], ofItemAtPath: writableFile.path)
        try fileManager.setAttributes([.posixPermissions: 0o777], ofItemAtPath: executableFile.path)
    }

    /// Sets up mock services with default behaviours
    func setupMockServices() {
        configureBookmarkServiceMock()
        configureKeychainServiceMock()
        configureLoggerMock()
    }

    /// Configures the bookmark service mock with default behaviours
    func configureBookmarkServiceMock() {
        mockBookmarkService.createBookmarkHandler = { url in
            try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        mockBookmarkService.resolveBookmarkHandler = { data in
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return (url, isStale)
        }
    }

    /// Configures the keychain service mock with default behaviours
    func configureKeychainServiceMock() {
        mockKeychainService.addCredentialsHandler = { _ in }
        mockKeychainService.updateCredentialsHandler = { _ in }
        mockKeychainService.removeCredentialsHandler = { _ in }
    }

    /// Configures the logger mock with default behaviours
    func configureLoggerMock() {
        mockLogger.logHandler = { _, _ in }
        mockLogger.logErrorHandler = { _, _ in }
        mockLogger.logWarningHandler = { _, _ in }
    }
}
