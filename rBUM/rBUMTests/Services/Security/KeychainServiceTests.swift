//
//  KeychainServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
import Security
@testable import rBUM

final class KeychainServiceTests: XCTestCase {
    let testService = "dev.mpy.rBUM.test"
    let testAccount = "testAccount"
    let testPassword = "testPassword123"
    
    func testCleanup() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Given a test item exists
        try await keychainService.storePassword(testPassword, forService: testService, account: testAccount)
        
        // When cleaning up
        try await cleanupKeychain()
        
        // Then the item should not exist
        do {
            _ = try await keychainService.retrievePassword(forService: testService, account: testAccount)
            XCTFail("Expected itemNotFound error")
        } catch let error as KeychainError {
            XCTAssertEqual(error, .itemNotFound)
        }
    }
    
    private func cleanupKeychain() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Try to delete the test item
        _ = try? await keychainService.deletePassword(forService: testService, account: testAccount)
        
        // Try to retrieve to verify it's gone - if this doesn't throw, something's wrong
        do {
            _ = try await keychainService.retrievePassword(forService: testService, account: testAccount)
            // If we get here, the item still exists - force delete it
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: testService,
                kSecAttrAccount as String: testAccount
            ]
            _ = SecItemDelete(query as CFDictionary)
            
            // Verify again
            _ = try await keychainService.retrievePassword(forService: testService, account: testAccount)
            throw KeychainError.unexpectedStatus(errSecSuccess) // If we get here, cleanup failed
        } catch KeychainError.itemNotFound {
            // This is what we want - item is gone
            return
        } catch {
            // Some other error occurred during verification
            throw error
        }
    }
    
    func testStorePassword() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Clean up before test
        try await cleanupKeychain()
        
        // When storing a new password
        try await keychainService.storePassword(testPassword, forService: testService, account: testAccount)
        
        // Then it should be retrievable
        let retrieved = try await keychainService.retrievePassword(forService: testService, account: testAccount)
        XCTAssertEqual(retrieved, testPassword)
        
        // Clean up after test
        try await cleanupKeychain()
    }
    
    func testStorePasswordOverwrite() async throws {
        let keychainService = KeychainService(isTest: true)
        let newPassword = "newPassword123"
        
        // Clean up before test
        try await cleanupKeychain()
        
        // Given an existing password
        try await keychainService.storePassword(testPassword, forService: testService, account: testAccount)
        
        // Verify initial password
        let initial = try await keychainService.retrievePassword(forService: testService, account: testAccount)
        XCTAssertEqual(initial, testPassword)
        
        // When storing a new password, it should overwrite
        try await keychainService.storePassword(newPassword, forService: testService, account: testAccount)
        
        // Then the new password should be retrievable
        let retrieved = try await keychainService.retrievePassword(forService: testService, account: testAccount)
        XCTAssertEqual(retrieved, newPassword)
        
        // Clean up after test
        try await cleanupKeychain()
    }
    
    func testUpdatePassword() async throws {
        let keychainService = KeychainService(isTest: true)
        let newPassword = "newTestPassword123"
        
        // Clean up before test
        try await cleanupKeychain()
        
        // Given an existing password
        try await keychainService.storePassword(testPassword, forService: testService, account: testAccount)
        
        // When updating the password
        try await keychainService.updatePassword(newPassword, forService: testService, account: testAccount)
        
        // Then it should be retrievable
        let retrieved = try await keychainService.retrievePassword(forService: testService, account: testAccount)
        XCTAssertEqual(retrieved, newPassword)
        
        // Clean up after test
        try await cleanupKeychain()
    }
    
    func testDeletePassword() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Clean up before test
        try await cleanupKeychain()
        
        // Given an existing password
        try await keychainService.storePassword(testPassword, forService: testService, account: testAccount)
        
        // Verify initial password exists
        let initial = try await keychainService.retrievePassword(forService: testService, account: testAccount)
        XCTAssertEqual(initial, testPassword)
        
        // When deleting the password
        try await keychainService.deletePassword(forService: testService, account: testAccount)
        
        // Then it should not be retrievable
        do {
            _ = try await keychainService.retrievePassword(forService: testService, account: testAccount)
            XCTFail("Expected itemNotFound error")
        } catch let error as KeychainError {
            XCTAssertEqual(error, .itemNotFound)
        }
    }
    
    func testMissingPassword() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Clean up before test
        try await cleanupKeychain()
        
        // When/Then retrieving a non-existent password should fail
        do {
            _ = try await keychainService.retrievePassword(forService: testService, account: testAccount)
            XCTFail("Expected itemNotFound error")
        } catch let error as KeychainError {
            XCTAssertEqual(error, .itemNotFound)
        }
    }
    
    func testUpdateNonexistentPassword() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Clean up before test
        try await cleanupKeychain()
        
        // When/Then updating a non-existent password should fail
        do {
            try await keychainService.updatePassword("newPassword", forService: testService, account: testAccount)
            XCTFail("Expected itemNotFound error")
        } catch let error as KeychainError {
            XCTAssertEqual(error, .itemNotFound)
        }
    }
    
    func testDeleteNonexistentPassword() async throws {
        let keychainService = KeychainService(isTest: true)
        
        // Clean up before test
        try await cleanupKeychain()
        
        // When/Then deleting a non-existent password should fail
        do {
            try await keychainService.deletePassword(forService: testService, account: testAccount)
            XCTFail("Expected itemNotFound error")
        } catch let error as KeychainError {
            XCTAssertEqual(error, .itemNotFound)
        }
    }
    
    override func setUp() async throws {
        try await super.setUp()
        try await cleanupKeychain()
    }
    
    override func tearDown() async throws {
        try await cleanupKeychain()
        try await super.tearDown()
    }
}
