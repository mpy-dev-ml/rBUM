//
//  SecurityServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
import CryptoKit
@testable import rBUM
@testable import Core

final class SecurityServiceTests: XCTestCase {
    // MARK: - Properties
    
    private var securityService: SecurityService!
    private var bookmarkService: MockBookmarkService!
    private var keychainService: MockKeychainService!
    private var logger: TestLogger!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        logger = TestLogger()
        bookmarkService = MockBookmarkService()
        keychainService = MockKeychainService()
        
        securityService = SecurityService(
            bookmarkService: bookmarkService,
            keychainService: keychainService,
            logger: logger
        )
    }
    
    override func tearDown() async throws {
        securityService = nil
        bookmarkService = nil
        keychainService = nil
        logger = nil
        try await super.tearDown()
    }
    
    // MARK: - Bookmark Tests
    
    func testCreateBookmark() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        let testData = "test-bookmark-data".data(using: .utf8)!
        bookmarkService.mockBookmarkData = testData
        
        let bookmarkData = try securityService.createBookmark(for: testURL)
        
        XCTAssertEqual(bookmarkData, testData)
        XCTAssertTrue(bookmarkService.createBookmarkCalled)
        XCTAssertEqual(bookmarkService.lastURL, testURL)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Created bookmark") })
    }
    
    func testResolveBookmark() throws {
        let testData = "test-bookmark-data".data(using: .utf8)!
        let testURL = URL(fileURLWithPath: "/test/path")
        bookmarkService.mockResolvedURL = testURL
        
        let resolvedURL = try securityService.resolveBookmark(testData)
        
        XCTAssertEqual(resolvedURL, testURL)
        XCTAssertTrue(bookmarkService.resolveBookmarkCalled)
        XCTAssertEqual(bookmarkService.lastBookmarkData, testData)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Resolved bookmark") })
    }
    
    func testBookmarkError() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        bookmarkService.shouldFail = true
        
        XCTAssertThrowsError(try securityService.createBookmark(for: testURL)) { error in
            XCTAssertTrue(error is BookmarkError)
        }
        
        // Verify error logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Failed to create bookmark") })
    }
    
    // MARK: - Credentials Tests
    
    func testSecureCredentials() throws {
        let testPassword = "test-password"
        let credentials = RepositoryCredentials(password: testPassword)
        
        let securedCredentials = try securityService.secureCredentials(credentials)
        
        XCTAssertNotEqual(securedCredentials.password, testPassword)
        XCTAssertTrue(securedCredentials.isEncrypted)
        XCTAssertTrue(keychainService.saveCredentialsCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Secured credentials") })
    }
    
    func testRetrieveCredentials() throws {
        let testPassword = "test-password"
        let repositoryId = UUID()
        keychainService.mockPassword = testPassword
        
        let credentials = try securityService.retrieveCredentials(for: repositoryId)
        
        XCTAssertEqual(credentials.password, testPassword)
        XCTAssertTrue(keychainService.retrieveCredentialsCalled)
        XCTAssertEqual(keychainService.lastRepositoryId, repositoryId)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Retrieved credentials") })
    }
    
    func testCredentialsError() throws {
        let credentials = RepositoryCredentials(password: "test-password")
        keychainService.shouldFail = true
        
        XCTAssertThrowsError(try securityService.secureCredentials(credentials)) { error in
            XCTAssertTrue(error is CredentialsError)
        }
        
        // Verify error logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Failed to secure credentials") })
    }
    
    // MARK: - Encryption Tests
    
    func testEncryptionKey() throws {
        let key1 = try securityService.generateEncryptionKey()
        let key2 = try securityService.generateEncryptionKey()
        
        XCTAssertNotEqual(key1, key2)
        XCTAssertEqual(key1.count, 32) // 256-bit key
    }
    
    func testDataEncryption() throws {
        let testData = "sensitive-data".data(using: .utf8)!
        let key = try securityService.generateEncryptionKey()
        
        let encryptedData = try securityService.encrypt(data: testData, using: key)
        XCTAssertNotEqual(encryptedData, testData)
        
        let decryptedData = try securityService.decrypt(data: encryptedData, using: key)
        XCTAssertEqual(decryptedData, testData)
    }
    
    func testEncryptionError() throws {
        let testData = "sensitive-data".data(using: .utf8)!
        let key = try securityService.generateEncryptionKey()
        
        // Modify encrypted data to cause decryption failure
        var encryptedData = try securityService.encrypt(data: testData, using: key)
        encryptedData[0] ^= 0xFF
        
        XCTAssertThrowsError(try securityService.decrypt(data: encryptedData, using: key)) { error in
            XCTAssertTrue(error is CryptoKitError)
        }
    }
    
    // MARK: - Sandbox Compliance Tests
    
    func testSandboxCompliance() throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        
        // Test bookmark creation with sandbox checks
        XCTAssertNoThrow(try securityService.createBookmark(for: testURL))
        XCTAssertTrue(bookmarkService.didCheckSandboxAccess)
        
        // Test bookmark resolution with sandbox checks
        let bookmarkData = try securityService.createBookmark(for: testURL)
        XCTAssertNoThrow(try securityService.resolveBookmark(bookmarkData))
        XCTAssertTrue(bookmarkService.didStartAccessing)
        XCTAssertTrue(bookmarkService.didStopAccessing)
    }
    
    func testConcurrentAccess() async throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        let iterations = 100
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    let bookmark = try self.securityService.createBookmark(for: testURL)
                    _ = try self.securityService.resolveBookmark(bookmark)
                }
            }
            try await group.waitForAll()
        }
        
        XCTAssertEqual(bookmarkService.createBookmarkCount, iterations)
        XCTAssertEqual(bookmarkService.resolveBookmarkCount, iterations)
        XCTAssertEqual(bookmarkService.startAccessingCount, iterations)
        XCTAssertEqual(bookmarkService.stopAccessingCount, iterations)
    }
}

// MARK: - Test Helpers

private final class MockBookmarkService {
    var createBookmarkCalled = false
    var resolveBookmarkCalled = false
    var didCheckSandboxAccess = false
    var didStartAccessing = false
    var didStopAccessing = false
    var shouldFail = false
    
    var createBookmarkCount = 0
    var resolveBookmarkCount = 0
    var startAccessingCount = 0
    var stopAccessingCount = 0
    
    var lastURL: URL?
    var lastBookmarkData: Data?
    
    var mockBookmarkData: Data?
    var mockResolvedURL: URL?
    
    func createBookmark(for url: URL) throws -> Data {
        createBookmarkCalled = true
        createBookmarkCount += 1
        lastURL = url
        didCheckSandboxAccess = true
        
        if shouldFail {
            throw BookmarkError.creationFailed
        }
        
        return mockBookmarkData ?? Data()
    }
    
    func resolveBookmark(_ data: Data) throws -> URL {
        resolveBookmarkCalled = true
        resolveBookmarkCount += 1
        lastBookmarkData = data
        
        if shouldFail {
            throw BookmarkError.resolutionFailed
        }
        
        return mockResolvedURL ?? URL(fileURLWithPath: "/test")
    }
    
    func startAccessing(_ url: URL) -> Bool {
        didStartAccessing = true
        startAccessingCount += 1
        return true
    }
    
    func stopAccessing(_ url: URL) {
        didStopAccessing = true
        stopAccessingCount += 1
    }
}

private final class MockKeychainService {
    var saveCredentialsCalled = false
    var retrieveCredentialsCalled = false
    var shouldFail = false
    
    var lastRepositoryId: UUID?
    var mockPassword: String?
    
    func saveCredentials(_ credentials: RepositoryCredentials, for repositoryId: UUID) throws {
        saveCredentialsCalled = true
        lastRepositoryId = repositoryId
        
        if shouldFail {
            throw CredentialsError.saveFailed
        }
    }
    
    func retrieveCredentials(for repositoryId: UUID) throws -> RepositoryCredentials {
        retrieveCredentialsCalled = true
        lastRepositoryId = repositoryId
        
        if shouldFail {
            throw CredentialsError.retrievalFailed
        }
        
        return RepositoryCredentials(password: mockPassword ?? "")
    }
}
