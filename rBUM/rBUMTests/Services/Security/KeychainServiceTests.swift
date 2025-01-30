//
//  KeychainServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Security
@testable import rBUM

struct KeychainServiceTests {
    // MARK: - Test Setup
    
    struct TestContext {
        let service: String
        let account: String
        let keychainService: KeychainService
        
        init(service: String = "dev.mpy.rBUM.test",
             account: String = "testAccount") {
            self.service = service
            self.account = account
            self.keychainService = KeychainService(isTest: true)
        }
        
        func cleanup() async throws {
            // Try to delete the test item
            _ = try? await keychainService.deletePassword(forService: service, account: account)
            
            // Verify deletion
            do {
                _ = try await keychainService.retrievePassword(forService: service, account: account)
                // If we get here, force delete it
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account
                ]
                _ = SecItemDelete(query as CFDictionary)
                
                // Verify again
                _ = try await keychainService.retrievePassword(forService: service, account: account)
                throw KeychainError.unexpectedStatus(errSecSuccess)
            } catch KeychainError.itemNotFound {
                return // Success - item is gone
            }
        }
    }
    
    // MARK: - Basic Operations Tests
    
    @Test("Store and retrieve passwords with various configurations",
          .tags(.core, .security, .integration),
          arguments: [
              (password: "simple-password", service: "dev.mpy.rBUM.test1", account: "account1"),
              (password: "Complex!@#$%^&*()", service: "dev.mpy.rBUM.test2", account: "account2"),
              (password: "password with spaces", service: "dev.mpy.rBUM.test3", account: "account3"),
              (password: "🔒unicode🔑", service: "dev.mpy.rBUM.test4", account: "account4"),
              (password: String(repeating: "a", count: 1024), service: "dev.mpy.rBUM.test5", account: "account5")
          ])
    func testStoreAndRetrievePassword(password: String, service: String, account: String) async throws {
        // Given
        let context = TestContext(service: service, account: account)
        try await context.cleanup()
        
        // When
        try await context.keychainService.storePassword(password, forService: service, account: account)
        let retrieved = try await context.keychainService.retrievePassword(forService: service, account: account)
        
        // Then
        #expect(retrieved == password)
        
        // Cleanup
        try await context.cleanup()
    }
    
    // MARK: - Update Tests
    
    @Test("Update passwords with various scenarios",
          .tags(.core, .security, .integration),
          arguments: [
              (initial: "initial123", updated: "updated123"),
              (initial: "short", updated: String(repeating: "a", count: 1024)),
              (initial: "Complex!@#", updated: "🔒unicode🔑")
          ])
    func testUpdatePassword(initial: String, updated: String) async throws {
        // Given
        let context = TestContext()
        try await context.cleanup()
        
        // When
        try await context.keychainService.storePassword(initial, forService: context.service, account: context.account)
        try await context.keychainService.updatePassword(updated, forService: context.service, account: context.account)
        
        // Then
        let retrieved = try await context.keychainService.retrievePassword(forService: context.service, account: context.account)
        #expect(retrieved == updated)
        #expect(retrieved != initial)
        
        // Cleanup
        try await context.cleanup()
    }
    
    // MARK: - Security Tests
    
    @Test("Handle various error scenarios",
          .tags(.core, .security, .error_handling),
          arguments: [
              (operation: "retrieve", expectedError: KeychainError.itemNotFound),
              (operation: "update", expectedError: KeychainError.itemNotFound),
              (operation: "delete", expectedError: KeychainError.itemNotFound)
          ])
    func testErrorScenarios(operation: String, expectedError: KeychainError) async throws {
        // Given
        let context = TestContext()
        try await context.cleanup()
        
        // When/Then
        switch operation {
        case "retrieve":
            await #expect(throws: expectedError) {
                _ = try await context.keychainService.retrievePassword(
                    forService: context.service,
                    account: context.account
                )
            }
        case "update":
            await #expect(throws: expectedError) {
                try await context.keychainService.updatePassword(
                    "newPassword",
                    forService: context.service,
                    account: context.account
                )
            }
        case "delete":
            await #expect(throws: expectedError) {
                try await context.keychainService.deletePassword(
                    forService: context.service,
                    account: context.account
                )
            }
        default:
            #expect(false, "Unknown operation: \(operation)")
        }
    }
    
    @Test("Handle concurrent access to same keychain item",
          .tags(.core, .security, .concurrency))
    func testConcurrentAccess() async throws {
        // Given
        let context = TestContext()
        try await context.cleanup()
        
        // Initial password
        try await context.keychainService.storePassword(
            "initial",
            forService: context.service,
            account: context.account
        )
        
        // When performing concurrent operations
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Multiple updates
            for i in 1...5 {
                group.addTask {
                    try await context.keychainService.updatePassword(
                        "password\(i)",
                        forService: context.service,
                        account: context.account
                    )
                }
            }
            
            // Concurrent reads
            for _ in 1...5 {
                group.addTask {
                    _ = try await context.keychainService.retrievePassword(
                        forService: context.service,
                        account: context.account
                    )
                }
            }
            
            try await group.waitForAll()
        }
        
        // Then - password should be one of the updates
        let finalPassword = try await context.keychainService.retrievePassword(
            forService: context.service,
            account: context.account
        )
        #expect(finalPassword.starts(with: "password"))
        
        // Cleanup
        try await context.cleanup()
    }
    
    @Test("Verify keychain item accessibility",
          .tags(.core, .security, .validation))
    func testKeychainAccessibility() async throws {
        // Given
        let context = TestContext()
        try await context.cleanup()
        
        let password = "testPassword123"
        try await context.keychainService.storePassword(
            password,
            forService: context.service,
            account: context.account
        )
        
        // Then - verify item attributes
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: context.service,
            kSecAttrAccount as String: context.account,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        #expect(status == errSecSuccess)
        
        if let attributes = result as? [String: Any] {
            // Verify accessibility setting
            let accessibility = attributes[kSecAttrAccessible as String] as? String
            #expect(accessibility == (kSecAttrAccessibleAfterFirstUnlock as String))
            
            // Verify proper ACL
            let accessControl = attributes[kSecAttrAccessControl as String]
            #expect(accessControl != nil)
        }
        
        // Cleanup
        try await context.cleanup()
    }
    
    @Test("Handle special characters in service and account names",
          .tags(.core, .security, .validation))
    func testSpecialCharacters() async throws {
        // Given
        let specialCases = [
            ("service with spaces", "account with spaces"),
            ("service/with/slashes", "account@with@at"),
            ("service.with.dots", "account_with_underscores"),
            ("service-with-dashes", "account#with#hash"),
            ("service🔒", "account🔑")
        ]
        
        // Test each case
        for (service, account) in specialCases {
            let context = TestContext(service: service, account: account)
            try await context.cleanup()
            
            // When
            try await context.keychainService.storePassword("test", forService: service, account: account)
            
            // Then
            let retrieved = try await context.keychainService.retrievePassword(forService: service, account: account)
            #expect(retrieved == "test")
            
            // Cleanup
            try await context.cleanup()
        }
    }
}
