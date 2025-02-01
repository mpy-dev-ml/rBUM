//
//  BackupSourceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupSource functionality
struct BackupSourceTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let fileManager: TestMocks.MockFileManager
        let notificationCenter: TestMocks.MockNotificationCenter
        let dateProvider: TestMocks.MockDateProvider
        
        init() {
            self.fileManager = TestMocks.MockFileManager()
            self.notificationCenter = TestMocks.MockNotificationCenter()
            self.dateProvider = TestMocks.MockDateProvider()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            fileManager.reset()
            notificationCenter.reset()
            dateProvider.reset()
        }
        
        /// Create test source manager
        func createSourceManager() -> BackupSourceManager {
            BackupSourceManager(
                fileManager: fileManager,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize source manager", ["init", "source"] as! TestTrait)
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating source manager
        let manager = context.createSourceManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.sourceCount == 0)
    }
    
    // MARK: - Source Creation Tests
    
    @Test("Test source creation", ["source", "create"] as! TestTrait)
    func testSourceCreation() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        let testData = MockData.Source.creationData
        
        // Test source creation
        for data in testData {
            // Create source
            let source = try manager.createSource(data)
            #expect(source.id != nil)
            #expect(context.fileManager.fileExistsCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify source
            let verified = try manager.verifySource(source)
            #expect(verified)
            #expect(context.fileManager.fileExistsCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Source Listing Tests
    
    @Test("Test source listing", ["source", "list"] as! TestTrait)
    func testSourceListing() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        let testCases = MockData.Source.listingData
        
        // Test source listing
        for testCase in testCases {
            // Add sources
            for source in testCase.sources {
                try manager.addSource(source)
            }
            
            // List sources
            let sources = try manager.listSources()
            #expect(sources.count == testCase.sources.count)
            
            // Filter sources
            let filtered = try manager.filterSources(sources, by: testCase.filter)
            #expect(filtered.count <= sources.count)
            
            context.reset()
        }
    }
    
    // MARK: - Source Update Tests
    
    @Test("Test source updates", ["source", "update"] as! TestTrait)
    func testSourceUpdates() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        let testCases = MockData.Source.updateData
        
        // Test source updates
        for testCase in testCases {
            // Create initial source
            let source = try manager.createSource(testCase.initial)
            
            // Update source
            let updated = try manager.updateSource(source, with: testCase.updates)
            #expect(updated.id == source.id)
            #expect(context.fileManager.fileExistsCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify updates
            for (key, value) in testCase.updates {
                #expect(updated.getValue(for: key) == value)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Source Deletion Tests
    
    @Test("Test source deletion", ["source", "delete"] as! TestTrait)
    func testSourceDeletion() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        let sources = MockData.Source.deletionData
        
        // Test source deletion
        for source in sources {
            // Add source
            try manager.addSource(source)
            
            // Delete source
            try manager.deleteSource(source)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify deletion
            let remaining = try manager.listSources()
            #expect(!remaining.contains(source))
            
            context.reset()
        }
    }
    
    // MARK: - Source Validation Tests
    
    @Test("Test source validation", ["source", "validate"] as! TestTrait)
    func testSourceValidation() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        let testCases = MockData.Source.validationData
        
        // Test source validation
        for testCase in testCases {
            // Validate source
            let isValid = try manager.validateSource(testCase.source)
            #expect(isValid == testCase.expectedValid)
            #expect(context.fileManager.fileExistsCalled)
            
            if !isValid {
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupSourceValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test source error handling", ["source", "error"] as! TestTrait)
    func testErrorHandling() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        let errorCases = MockData.Source.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleSourceOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupSourceError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle source edge cases", ["source", "edge"] as! TestTrait)
    func testEdgeCases() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        // Test invalid path
        do {
            try manager.createSource(path: "/non/existent/path")
            throw TestFailure("Expected error for invalid path")
        } catch {
            // Expected error
        }
        
        // Test duplicate source
        do {
            let source = try manager.createSource(path: "/test/path")
            try manager.addSource(source)
            try manager.addSource(source)
            throw TestFailure("Expected error for duplicate source")
        } catch {
            // Expected error
        }
        
        // Test empty source list
        do {
            let sources = try manager.listSources()
            #expect(sources.isEmpty)
        } catch {
            throw TestFailure("Unexpected error for empty source list")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test source performance", ["source", "performance"] as! TestTrait)
    func testPerformance() throws {
        // Given: Source manager
        let context = TestContext()
        let manager = context.createSourceManager()
        
        // Test listing performance
        let startTime = context.dateProvider.now()
        
        for _ in 0..<100 {
            _ = try manager.listSources()
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test validation performance
        let source = try manager.createSource(path: "/test/path")
        let validationStartTime = context.dateProvider.now()
        
        for _ in 0..<1000 {
            _ = try manager.validateSource(source)
        }
        
        let validationEndTime = context.dateProvider.now()
        
        let validationInterval = validationEndTime.timeIntervalSince(validationStartTime)
        #expect(validationInterval < 0.5) // Validation should be fast
    }
}
