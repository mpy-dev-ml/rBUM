//
//  RepositoryStorageTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for RepositoryStorage functionality
struct RepositoryStorageTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let fileManager: MockFileManager
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let encoder: JSONEncoder
        let decoder: JSONDecoder
        
        init() {
            self.fileManager = MockFileManager()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.encoder = JSONEncoder()
            self.decoder = JSONDecoder()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            fileManager.reset()
            notificationCenter.reset()
            dateProvider.reset()
        }
        
        /// Create test repository storage
        func createStorage() -> RepositoryStorage {
            RepositoryStorage(
                fileManager: fileManager,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                encoder: encoder,
                decoder: decoder
            )
        }
    }
    
    // MARK: - Storage Tests
    
    @Test("Test repository storage operations", tags: ["storage", "repository"])
    func testStorageOperations() throws {
        // Given: Repository storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Repository.storageData
        
        // Test storage operations
        for testCase in testCases {
            // Store repository
            try storage.store(testCase.repository)
            #expect(context.fileManager.createFileCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Load repository
            let loaded = try storage.load(testCase.repository.id)
            #expect(loaded == testCase.repository)
            
            // Update repository
            var updated = testCase.repository
            updated.name = "Updated \(testCase.repository.name)"
            try storage.update(updated)
            #expect(context.fileManager.writeDataCalled)
            
            // Delete repository
            try storage.delete(updated.id)
            #expect(context.fileManager.removeItemCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Query Tests
    
    @Test("Test repository queries", tags: ["storage", "query"])
    func testRepositoryQueries() throws {
        // Given: Repository storage with test data
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Repository.queryData
        
        // Store test repositories
        for data in testCases.repositories {
            try storage.store(data)
        }
        
        // Test queries
        for query in testCases.queries {
            // Execute query
            let results = try storage.query(query.filter)
            #expect(results.count == query.expectedCount)
            
            // Verify results
            for (result, expected) in zip(results, query.expectedResults) {
                #expect(result == expected)
            }
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Test repository validation", tags: ["storage", "validate"])
    func testRepositoryValidation() throws {
        // Given: Repository storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Repository.validationData
        
        // Test validation
        for testCase in testCases {
            do {
                // Validate repository
                try storage.validate(testCase.repository)
                
                if !testCase.expectedValid {
                    throw TestFailure("Expected validation error for invalid data")
                }
            } catch {
                if testCase.expectedValid {
                    throw TestFailure("Unexpected validation error: \(error)")
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Migration Tests
    
    @Test("Test repository storage migration", tags: ["storage", "migration"])
    func testStorageMigration() throws {
        // Given: Repository storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Repository.migrationData
        
        // Test migration
        for testCase in testCases {
            // Setup old data
            context.fileManager.mockFileData = testCase.oldData
            
            // Perform migration
            try storage.migrate()
            
            // Verify migration
            let migratedData = context.fileManager.lastWrittenData
            #expect(migratedData == testCase.expectedData)
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test storage error handling", tags: ["storage", "error"])
    func testErrorHandling() throws {
        // Given: Repository storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let errorCases = MockData.Repository.storageErrorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                // Simulate error condition
                context.fileManager.simulateError = errorCase.error
                
                // Attempt operation
                try errorCase.operation(storage)
                
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Verify error handling
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryStorageError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Test concurrent storage operations", tags: ["storage", "concurrent"])
    func testConcurrentOperations() throws {
        // Given: Repository storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let testCases = MockData.Repository.concurrentData
        
        // Test concurrent operations
        for testCase in testCases {
            // Perform concurrent operations
            let group = DispatchGroup()
            var errors: [Error] = []
            
            for operation in testCase.operations {
                group.enter()
                DispatchQueue.global().async {
                    do {
                        try operation(storage)
                    } catch {
                        errors.append(error)
                    }
                    group.leave()
                }
            }
            
            group.wait()
            
            // Verify results
            #expect(errors.count == testCase.expectedErrorCount)
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test storage performance", tags: ["storage", "performance"])
    func testPerformance() throws {
        // Given: Repository storage
        let context = TestContext()
        let storage = context.createStorage()
        
        let startTime = Date()
        
        // Perform multiple operations
        for i in 0..<100 {
            let repository = Repository(
                name: "Performance Test \(i)",
                path: URL(fileURLWithPath: "/test/path/\(i)")
            )
            try storage.store(repository)
            _ = try storage.load(repository.id)
            try storage.delete(repository.id)
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual operation performance
        let repository = Repository(
            name: "Performance Test",
            path: URL(fileURLWithPath: "/test/path")
        )
        
        let operationStart = Date()
        try storage.store(repository)
        _ = try storage.load(repository.id)
        try storage.delete(repository.id)
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.1) // Individual operations should be fast
    }
}
