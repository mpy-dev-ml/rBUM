//
//  KeychainServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
import Security
@testable import rBUM
@testable import Core

final class KeychainServiceTests: XCTestCase {
    // MARK: - Properties
    
    private var keychainService: KeychainService!
    private var logger: TestLogger!
    private let serviceName = "dev.mpy.rBUM"
    private let accessGroup = "dev.mpy.rBUM.shared"
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        logger = TestLogger()
        keychainService = KeychainService(
            serviceName: serviceName,
            accessGroup: accessGroup,
            logger: logger
        )
        
        // Clean up any existing test items
        try cleanupTestItems()
    }
    
    override func tearDown() async throws {
        try cleanupTestItems()
        keychainService = nil
        logger = nil
        try await super.tearDown()
    }
    
    private func cleanupTestItems() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccessGroup as String: accessGroup,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Credential Tests
    
    func testSaveAndRetrieveCredentials() throws {
        let repositoryId = UUID()
        let credentials = RepositoryCredentials(password: "test-password")
        
        // Save credentials
        try keychainService.saveCredentials(credentials, for: repositoryId)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Saving credentials") })
        
        // Retrieve credentials
        let retrieved = try keychainService.retrieveCredentials(for: repositoryId)
        
        XCTAssertEqual(retrieved.password, credentials.password)
        XCTAssertTrue(logger.messages.contains { $0.contains("Retrieved credentials") })
    }
    
    func testUpdateCredentials() throws {
        let repositoryId = UUID()
        let originalCredentials = RepositoryCredentials(password: "original-password")
        let updatedCredentials = RepositoryCredentials(password: "updated-password")
        
        // Save original credentials
        try keychainService.saveCredentials(originalCredentials, for: repositoryId)
        
        // Update credentials
        try keychainService.saveCredentials(updatedCredentials, for: repositoryId)
        
        // Retrieve and verify
        let retrieved = try keychainService.retrieveCredentials(for: repositoryId)
        XCTAssertEqual(retrieved.password, updatedCredentials.password)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Updating credentials") })
    }
    
    func testDeleteCredentials() throws {
        let repositoryId = UUID()
        let credentials = RepositoryCredentials(password: "test-password")
        
        // Save credentials
        try keychainService.saveCredentials(credentials, for: repositoryId)
        
        // Delete credentials
        try keychainService.deleteCredentials(for: repositoryId)
        
        // Verify deletion
        XCTAssertThrowsError(try keychainService.retrieveCredentials(for: repositoryId)) { error in
            XCTAssertEqual(error as? CredentialsError, .retrievalFailed)
        }
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Deleted credentials") })
    }
    
    // MARK: - Security Tests
    
    func testCredentialEncryption() throws {
        let repositoryId = UUID()
        let credentials = RepositoryCredentials(password: "sensitive-password")
        
        // Save credentials
        try keychainService.saveCredentials(credentials, for: repositoryId)
        
        // Verify encryption
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: repositoryId.uuidString,
            kSecAttrAccessGroup as String: accessGroup,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        
        let storedData = result as! Data
        let rawString = String(data: storedData, encoding: .utf8)
        
        // Verify that stored data is encrypted (not plaintext)
        XCTAssertNotEqual(rawString, credentials.password)
    }
    
    func testAccessControl() throws {
        let repositoryId = UUID()
        let credentials = RepositoryCredentials(password: "test-password")
        
        // Save credentials with access control
        try keychainService.saveCredentials(credentials, for: repositoryId)
        
        // Verify access control attributes
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: repositoryId.uuidString,
            kSecAttrAccessGroup as String: accessGroup,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        
        let attributes = result as! [String: Any]
        XCTAssertNotNil(attributes[kSecAttrAccessControl as String])
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCredentials() throws {
        let repositoryId = UUID()
        
        // Test retrieving non-existent credentials
        XCTAssertThrowsError(try keychainService.retrieveCredentials(for: repositoryId)) { error in
            XCTAssertEqual(error as? CredentialsError, .retrievalFailed)
        }
        
        // Verify error logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Failed to retrieve credentials") })
    }
    
    func testDuplicateCredentials() throws {
        let repositoryId = UUID()
        let credentials1 = RepositoryCredentials(password: "password1")
        let credentials2 = RepositoryCredentials(password: "password2")
        
        // Save first credentials
        try keychainService.saveCredentials(credentials1, for: repositoryId)
        
        // Save second credentials (should update, not error)
        XCTAssertNoThrow(try keychainService.saveCredentials(credentials2, for: repositoryId))
        
        // Verify only the second credentials are stored
        let retrieved = try keychainService.retrieveCredentials(for: repositoryId)
        XCTAssertEqual(retrieved.password, credentials2.password)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAccess() async throws {
        let iterations = 100
        let repositoryIds = (0..<iterations).map { _ in UUID() }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in repositoryIds {
                group.addTask {
                    let credentials = RepositoryCredentials(password: "password-\(id)")
                    try self.keychainService.saveCredentials(credentials, for: id)
                    let retrieved = try self.keychainService.retrieveCredentials(for: id)
                    XCTAssertEqual(retrieved.password, credentials.password)
                }
            }
            try await group.waitForAll()
        }
    }
    
    func testConcurrentModification() async throws {
        let repositoryId = UUID()
        let iterations = 100
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let credentials = RepositoryCredentials(password: "password-\(i)")
                    try self.keychainService.saveCredentials(credentials, for: repositoryId)
                    _ = try self.keychainService.retrieveCredentials(for: repositoryId)
                }
            }
            try await group.waitForAll()
        }
        
        // Verify only one credential exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: repositoryId.uuidString,
            kSecAttrAccessGroup as String: accessGroup,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        XCTAssertEqual(status, errSecSuccess)
        
        let items = result as! [[String: Any]]
        XCTAssertEqual(items.count, 1)
    }
}
