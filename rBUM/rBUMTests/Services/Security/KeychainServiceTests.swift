//
//  KeychainServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for KeychainService functionality
struct KeychainServiceTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let keychain: MockKeychain
        let notificationCenter: MockNotificationCenter
        let encoder: JSONEncoder
        let decoder: JSONDecoder
        
        init() {
            self.keychain = MockKeychain()
            self.notificationCenter = MockNotificationCenter()
            self.encoder = JSONEncoder()
            self.decoder = JSONDecoder()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            keychain.reset()
            notificationCenter.reset()
        }
        
        /// Create test keychain service
        func createService() -> KeychainService {
            KeychainService(
                keychain: keychain,
                notificationCenter: notificationCenter,
                encoder: encoder,
                decoder: decoder
            )
        }
    }
    
    // MARK: - Storage Tests
    
    @Test("Store and retrieve keychain items", tags: ["keychain", "storage"])
    func testKeychainStorage() throws {
        // Given: Keychain service
        let context = TestContext()
        let service = context.createService()
        let item = MockData.Keychain.validItem
        
        // When: Storing item
        try service.store(item)
        
        // Then: Item is stored and can be retrieved
        let retrieved = try service.get(id: item.id)
        #expect(retrieved == item)
        #expect(context.keychain.addCalled)
        #expect(!service.showError)
    }
    
    @Test("Handle invalid items", tags: ["keychain", "error"])
    func testInvalidItems() throws {
        // Given: Keychain service with failing keychain
        let context = TestContext()
        let service = context.createService()
        let item = MockData.Keychain.invalidItem
        
        context.keychain.shouldFail = true
        context.keychain.error = MockData.Error.keychainError
        
        // When/Then: Storing invalid item fails
        #expect(throws: MockData.Error.keychainError) {
            try service.store(item)
        }
        
        #expect(service.showError)
        #expect(service.error as? MockData.Error == MockData.Error.keychainError)
    }
    
    @Test("Update keychain items", tags: ["keychain", "update"])
    func testKeychainUpdate() throws {
        // Given: Keychain service with existing item
        let context = TestContext()
        let service = context.createService()
        let oldItem = MockData.Keychain.validItem
        let newItem = MockData.Keychain.updatedItem
        
        try service.store(oldItem)
        
        // When: Updating item
        try service.update(newItem)
        
        // Then: Item is updated
        let retrieved = try service.get(id: newItem.id)
        #expect(retrieved == newItem)
        #expect(context.keychain.updateCalled)
        #expect(!service.showError)
    }
    
    @Test("Delete keychain items", tags: ["keychain", "delete"])
    func testKeychainDeletion() throws {
        // Given: Keychain service with stored item
        let context = TestContext()
        let service = context.createService()
        let item = MockData.Keychain.validItem
        
        try service.store(item)
        
        // When: Deleting item
        try service.delete(id: item.id)
        
        // Then: Item is removed
        #expect(context.keychain.deleteCalled)
        #expect(!service.showError)
        #expect(throws: KeychainError.itemNotFound) {
            _ = try service.get(id: item.id)
        }
    }
    
    @Test("List keychain items", tags: ["keychain", "list"])
    func testKeychainListing() throws {
        // Given: Keychain service with multiple items
        let context = TestContext()
        let service = context.createService()
        let items = MockData.Keychain.multipleItems
        
        for item in items {
            try service.store(item)
        }
        
        // When: Listing items
        let listed = try service.list()
        
        // Then: All items are listed
        #expect(listed.count == items.count)
        for item in items {
            #expect(listed.contains(where: { $0.id == item.id }))
        }
        #expect(!service.showError)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test keychain performance", tags: ["keychain", "performance"])
    func testKeychainPerformance() throws {
        // Given: Keychain service
        let context = TestContext()
        let service = context.createService()
        let items = MockData.Keychain.multipleItems
        
        // When: Performing multiple operations
        let startTime = Date()
        
        // Store items
        for item in items {
            try service.store(item)
        }
        
        // Retrieve items
        for item in items {
            _ = try service.get(id: item.id)
        }
        
        // List items
        _ = try service.list()
        
        // Delete items
        for item in items {
            try service.delete(id: item.id)
        }
        
        let endTime = Date()
        
        // Then: Operations complete within reasonable time
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // All operations should complete within 1 second
    }
}

// MARK: - Mock Keychain

final class MockKeychain: KeychainProtocol {
    private var storage: [String: Data] = [:]
    private(set) var addCalled = false
    private(set) var updateCalled = false
    private(set) var deleteCalled = false
    var shouldFail = false
    var error: Error?
    
    func add(_ data: Data, for key: String) throws {
        if shouldFail {
            throw error!
        }
        storage[key] = data
        addCalled = true
    }
    
    func get(for key: String) throws -> Data {
        if shouldFail {
            throw error!
        }
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func update(_ data: Data, for key: String) throws {
        if shouldFail {
            throw error!
        }
        storage[key] = data
        updateCalled = true
    }
    
    func delete(for key: String) throws {
        if shouldFail {
            throw error!
        }
        storage.removeValue(forKey: key)
        deleteCalled = true
    }
    
    func list() throws -> [String] {
        if shouldFail {
            throw error!
        }
        return Array(storage.keys)
    }
    
    func reset() {
        storage.removeAll()
        addCalled = false
        updateCalled = false
        deleteCalled = false
        shouldFail = false
        error = nil
    }
}
