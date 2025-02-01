//
//  BackupTagTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupTag functionality
struct BackupTagTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let notificationCenter: TestMocks.MockNotificationCenter
        let dateProvider: TestMocks.MockDateProvider
        let fileManager: TestMocks.MockFileManager
        
        init() {
            self.notificationCenter = TestMocks.MockNotificationCenter()
            self.dateProvider = TestMocks.MockDateProvider()
            self.fileManager = TestMocks.MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            notificationCenter.reset()
            dateProvider.reset()
            fileManager.reset()
        }
        
        /// Create test tag manager
        func createTagManager() -> BackupTagManager {
            BackupTagManager(
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                fileManager: fileManager
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize tag manager", tags: ["init", "tag"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating tag manager
        let manager = context.createTagManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.tagCount == 0)
    }
    
    // MARK: - Tag Creation Tests
    
    @Test("Test tag creation", tags: ["tag", "create"])
    func testTagCreation() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testData = MockData.Tag.creationData
        
        // Test tag creation
        for data in testData {
            // Create tag
            let tag = try manager.createTag(data)
            #expect(tag.id != nil)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify tag
            let verified = try manager.verifyTag(tag)
            #expect(verified)
            
            context.reset()
        }
    }
    
    // MARK: - Tag Listing Tests
    
    @Test("Test tag listing", tags: ["tag", "list"])
    func testTagListing() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testCases = MockData.Tag.listingData
        
        // Test tag listing
        for testCase in testCases {
            // Add tags
            for tag in testCase.tags {
                try manager.addTag(tag)
            }
            
            // List tags
            let tags = try manager.listTags()
            #expect(tags.count == testCase.tags.count)
            
            // Filter tags
            let filtered = try manager.filterTags(tags, by: testCase.filter)
            #expect(filtered.count <= tags.count)
            
            context.reset()
        }
    }
    
    // MARK: - Tag Update Tests
    
    @Test("Test tag updates", tags: ["tag", "update"])
    func testTagUpdates() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testCases = MockData.Tag.updateData
        
        // Test tag updates
        for testCase in testCases {
            // Create initial tag
            let tag = try manager.createTag(testCase.initial)
            
            // Update tag
            let updated = try manager.updateTag(tag, with: testCase.updates)
            #expect(updated.id == tag.id)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify updates
            for (key, value) in testCase.updates {
                #expect(updated.getValue(for: key) == value)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Tag Deletion Tests
    
    @Test("Test tag deletion", tags: ["tag", "delete"])
    func testTagDeletion() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let tags = MockData.Tag.deletionData
        
        // Test tag deletion
        for tag in tags {
            // Add tag
            try manager.addTag(tag)
            
            // Delete tag
            try manager.deleteTag(tag)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify deletion
            let remaining = try manager.listTags()
            #expect(!remaining.contains(tag))
            
            context.reset()
        }
    }
    
    // MARK: - Tag Association Tests
    
    @Test("Test tag associations", tags: ["tag", "associate"])
    func testTagAssociations() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testCases = MockData.Tag.associationData
        
        // Test tag associations
        for testCase in testCases {
            // Create tag and target
            let tag = try manager.createTag(testCase.tag)
            
            // Associate tag
            try manager.associateTag(tag, with: testCase.target)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify association
            let associated = try manager.getAssociatedTags(for: testCase.target)
            #expect(associated.contains(tag))
            
            context.reset()
        }
    }
    
    // MARK: - Tag Validation Tests
    
    @Test("Test tag validation", tags: ["tag", "validate"])
    func testTagValidation() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testCases = MockData.Tag.validationData
        
        // Test tag validation
        for testCase in testCases {
            // Validate tag
            let isValid = try manager.validateTag(testCase.tag)
            #expect(isValid == testCase.expectedValid)
            
            if !isValid {
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupTagValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test tag error handling", tags: ["tag", "error"])
    func testErrorHandling() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let errorCases = MockData.Tag.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleTagOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupTagError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle tag edge cases", tags: ["tag", "edge"])
    func testEdgeCases() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Test invalid tag
        do {
            try manager.verifyTag(BackupTag(id: "invalid"))
            throw TestFailure("Expected error for invalid tag")
        } catch {
            // Expected error
        }
        
        // Test duplicate tag
        do {
            let tag = try manager.createTag(name: "test")
            try manager.addTag(tag)
            try manager.addTag(tag)
            throw TestFailure("Expected error for duplicate tag")
        } catch {
            // Expected error
        }
        
        // Test empty tag list
        do {
            let tags = try manager.listTags()
            #expect(tags.isEmpty)
        } catch {
            throw TestFailure("Unexpected error for empty tag list")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test tag performance", tags: ["tag", "performance"])
    func testPerformance() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Test listing performance
        let startTime = context.dateProvider.now()
        
        for _ in 0..<100 {
            _ = try manager.listTags()
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test validation performance
        let tag = try manager.createTag(name: "test")
        let validationStartTime = context.dateProvider.now()
        
        for _ in 0..<1000 {
            _ = try manager.validateTag(tag)
        }
        
        let validationEndTime = context.dateProvider.now()
        
        let validationInterval = validationEndTime.timeIntervalSince(validationStartTime)
        #expect(validationInterval < 0.5) // Validation should be fast
    }
}
