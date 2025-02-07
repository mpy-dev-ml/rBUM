//
//  SecurityTestUtilities.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
@testable import rBUM
import XCTest

// MARK: - Test URL Extensions

extension URL {
    static func temporaryTestDirectory(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func temporaryTestFile(name: String, content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Test Data Extensions

extension Data {
    static func testBookmark(for url: URL) -> Data {
        "test-bookmark-\(url.lastPathComponent)".data(using: .utf8)!
    }
}

// MARK: - Test Error Types

enum TestError: Error {
    case testFailure(String)
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    func cleanupTestURLs(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func verifyLogMessages(_ logger: MockLogger, contains messages: String...) {
        for message in messages {
            XCTAssertTrue(logger.containsMessage(message), "Log should contain message: \(message)")
        }
    }
}

// MARK: - Test Environment Setup

struct TestEnvironment {
    let fileManager: FileManager
    let testDirectory: URL
    let sourceDirectory: URL
    let destinationDirectory: URL
    let bookmarkDirectory: URL
    let mockServices: MockServices
}

struct MockServices {
    let bookmarkService: MockBookmarkService
    let securityService: MockSecurityService
    let keychainService: MockKeychainService
}

struct MockBookmarkService {
    var createBookmarkHandler: (URL) throws -> Data
    var resolveBookmarkHandler: (Data) throws -> URL
}

struct MockSecurityService {
    var validateAccessHandler: (URL) -> Bool
    var validateWriteAccessHandler: (URL) -> Bool
    var validateReadAccessHandler: (URL) -> Bool
}

struct MockKeychainService {
    var saveHandler: (String, String, Data) -> Bool
    var loadHandler: (String, String) -> Data?
    var deleteHandler: (String, String) -> Bool
}

extension XCTestCase {
    static func setupTestEnvironment() async throws -> TestEnvironment {
        let environment = try await createTestEnvironment()
        try await setupTestDirectories(in: environment)
        try await setupTestFiles(in: environment)
        try await setupTestBookmarks(in: environment)
        return environment
    }
    
    private static func createTestEnvironment() async throws -> TestEnvironment {
        let fileManager = FileManager.default
        let testDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        return TestEnvironment(
            fileManager: fileManager,
            testDirectory: testDirectory,
            sourceDirectory: testDirectory.appendingPathComponent("source"),
            destinationDirectory: testDirectory.appendingPathComponent("destination"),
            bookmarkDirectory: testDirectory.appendingPathComponent("bookmarks"),
            mockServices: createMockServices()
        )
    }
    
    private static func setupTestDirectories(in environment: TestEnvironment) async throws {
        // Create main test directory
        try environment.fileManager.createDirectory(
            at: environment.testDirectory,
            withIntermediateDirectories: true
        )
        
        // Create subdirectories
        try environment.fileManager.createDirectory(
            at: environment.sourceDirectory,
            withIntermediateDirectories: true
        )
        
        try environment.fileManager.createDirectory(
            at: environment.destinationDirectory,
            withIntermediateDirectories: true
        )
        
        try environment.fileManager.createDirectory(
            at: environment.bookmarkDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private static func setupTestFiles(in environment: TestEnvironment) async throws {
        // Create test files with different permissions
        try createTestFile(
            named: "readable.txt",
            content: "Readable content",
            permissions: [.readable],
            in: environment
        )
        
        try createTestFile(
            named: "writable.txt",
            content: "Writable content",
            permissions: [.writable],
            in: environment
        )
        
        try createTestFile(
            named: "executable.txt",
            content: "Executable content",
            permissions: [.executable],
            in: environment
        )
        
        try createTestFile(
            named: "full-access.txt",
            content: "Full access content",
            permissions: [.readable, .writable, .executable],
            in: environment
        )
    }
    
    private static func setupTestBookmarks(in environment: TestEnvironment) async throws {
        // Create bookmarks for test files
        let files = try environment.fileManager.contentsOfDirectory(
            at: environment.sourceDirectory,
            includingPropertiesForKeys: nil
        )
        
        for file in files {
            try await createTestBookmark(for: file, in: environment)
        }
    }
    
    private static func createTestFile(
        named name: String,
        content: String,
        permissions: Set<FilePermission>,
        in environment: TestEnvironment
    ) throws {
        let filePath = environment.sourceDirectory.appendingPathComponent(name)
        try content.write(to: filePath, atomically: true, encoding: .utf8)
        
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
        try environment.fileManager.setAttributes(attributes, ofItemAtPath: filePath.path)
    }
    
    private static func createTestBookmark(for url: URL, in environment: TestEnvironment) async throws {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        let bookmarkFile = environment.bookmarkDirectory
            .appendingPathComponent(url.lastPathComponent)
            .appendingPathExtension("bookmark")
        
        try bookmark.write(to: bookmarkFile)
    }
    
    private static func createMockServices() -> MockServices {
        let bookmarkService = MockBookmarkService()
        let securityService = MockSecurityService()
        let keychainService = MockKeychainService()
        
        configureMockBookmarkService(bookmarkService)
        configureMockSecurityService(securityService)
        configureMockKeychainService(keychainService)
        
        return MockServices(
            bookmarkService: bookmarkService,
            securityService: securityService,
            keychainService: keychainService
        )
    }
    
    private static func configureMockBookmarkService(_ service: MockBookmarkService) {
        service.createBookmarkHandler = { url in
            try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        
        service.resolveBookmarkHandler = { data in
            var isStale = false
            return try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }
    }
    
    private static func configureMockSecurityService(_ service: MockSecurityService) {
        service.validateAccessHandler = { url in
            FileManager.default.fileExists(atPath: url.path)
        }
        
        service.validateWriteAccessHandler = { url in
            FileManager.default.isWritableFile(atPath: url.path)
        }
        
        service.validateReadAccessHandler = { url in
            FileManager.default.isReadableFile(atPath: url.path)
        }
    }
    
    private static func configureMockKeychainService(_ service: MockKeychainService) {
        service.saveHandler = { _, _, _ in true }
        service.loadHandler = { _, _ in "test-data".data(using: .utf8) }
        service.deleteHandler = { _, _ in true }
    }
    
    // MARK: - Test Environment Cleanup
    
    static func cleanupTestEnvironment(_ environment: TestEnvironment) throws {
        try cleanupTestFiles(in: environment)
        try cleanupTestDirectories(in: environment)
        try cleanupTestBookmarks(in: environment)
    }
    
    private static func cleanupTestFiles(in environment: TestEnvironment) throws {
        let files = try environment.fileManager.contentsOfDirectory(
            at: environment.sourceDirectory,
            includingPropertiesForKeys: nil
        )
        
        for file in files {
            try environment.fileManager.removeItem(at: file)
        }
    }
    
    private static func cleanupTestDirectories(in environment: TestEnvironment) throws {
        try environment.fileManager.removeItem(at: environment.testDirectory)
    }
    
    private static func cleanupTestBookmarks(in environment: TestEnvironment) throws {
        let bookmarks = try environment.fileManager.contentsOfDirectory(
            at: environment.bookmarkDirectory,
            includingPropertiesForKeys: nil
        )
        
        for bookmark in bookmarks {
            try environment.fileManager.removeItem(at: bookmark)
        }
    }
}

enum FilePermission: String {
    case readable = "readable"
    case writable = "writable"
    case executable = "executable"
}
