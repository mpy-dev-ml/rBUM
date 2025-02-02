//
//  BackupTagTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

/// Tests for BackupTag functionality
struct BackupTagTests {
    // MARK: - Test Types
    
    typealias TestMocks = TestMocksModule.TestMocks
    
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let notificationCenter: NotificationCenter
        let dateProvider: DateProviderProtocol
        let fileManager: FileManagerProtocol
        
        init() {
            self.notificationCenter = TestMocks.MockNotificationCenter()
            self.dateProvider = TestMocks.MockDateProvider()
            self.fileManager = TestMocks.MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            (notificationCenter as? TestMocks.MockNotificationCenter)?.reset()
            (dateProvider as? TestMocks.MockDateProvider)?.reset()
            (fileManager as? TestMocks.MockFileManager)?.reset()
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
    
    // MARK: - Test Data
    
    enum MockData {
        struct Tag {
            static let basicTags: [(
                name: String,
                description: String?,
                shouldSucceed: Bool,
                expectedError: BackupTagError?
            )] = [
                ("Test Tag", nil, true, nil),
                ("Development", "For development backups", true, nil),
                ("", nil, false, .invalidName),
                ("Test Tag", nil, false, .invalidName) // Duplicate
            ]
            
            static let updateTags: [(
                name: String,
                description: String?,
                newName: String,
                newDescription: String?,
                shouldSucceed: Bool,
                expectedError: BackupTagError?
            )] = [
                ("Test Tag", nil, "Updated Tag", "New description", true, nil),
                ("Test Tag", nil, "", nil, false, .invalidName)
            ]
            
            static let associationTags: [(
                name: String,
                backupId: String,
                shouldSucceed: Bool,
                expectedError: BackupTagError?
            )] = [
                ("Test Tag", "backup-123", true, nil),
                ("Invalid Tag", "backup-123", false, .tagNotFound)
            ]
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Test tag manager initialization", ["tag", "init"] as! TestTrait)
    func testInitialization() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Then: Verify initial state
        let tags = try manager.getAllTags()
        #expect(tags.isEmpty)
    }
    
    // MARK: - Basic Tests
    
    @Test("Test basic tag operations", ["tag", "basic"] as! TestTrait)
    func testBasicOperations() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // When/Then: Test basic tag operations
        for testCase in MockData.Tag.basicTags {
            do {
                let tag = try manager.createTag(
                    name: testCase.name,
                    description: testCase.description
                )
                
                if !testCase.shouldSucceed {
                    throw TestFailure("Expected error for invalid tag")
                }
                
                // Verify tag properties
                #expect(tag.name == testCase.name)
                #expect(tag.description == testCase.description)
                
                // Verify tag is in list
                let tags = try manager.getAllTags()
                #expect(tags.contains(where: { $0.id == tag.id }))
                
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected error: \(error)")
                }
                
                if let error = error as? BackupTagError {
                    #expect(error == testCase.expectedError)
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Tag Creation Tests
    
    @Test("Test tag creation", ["tag", "create"] as! TestTrait)
    func testTagCreation() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testData = MockData.Tag.basicTags
        
        // Test tag creation
        for data in testData {
            // Create tag
            let tag = try manager.createTag(name: data.name, description: data.description)
            #expect(tag.id != nil)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify tag
            let verified = try manager.verifyTag(tag)
            #expect(verified)
            
            context.reset()
        }
    }
    
    // MARK: - Tag Listing Tests
    
    @Test("Test tag listing", ["tag", "list"] as! TestTrait)
    func testTagListing() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        let testCases = MockData.Tag.basicTags
        
        // Test tag listing
        for testCase in testCases {
            // Add tags
            for _ in 0..<5 {
                try manager.createTag(name: testCase.name, description: testCase.description)
            }
            
            // List tags
            let tags = try manager.listTags()
            #expect(tags.count == 5)
            
            // Filter tags
            let filtered = try manager.filterTags(tags, by: nil)
            #expect(filtered.count <= tags.count)
            
            context.reset()
        }
    }
    
    // MARK: - Tag Update Tests
    
    @Test("Test tag updates", ["tag", "update"] as! TestTrait)
    func testTagUpdates() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // When/Then: Test tag updates
        for testCase in MockData.Tag.updateTags {
            do {
                let tag = try manager.createTag(
                    name: testCase.name,
                    description: testCase.description
                )
                
                try manager.updateTag(
                    tag,
                    name: testCase.newName,
                    description: testCase.newDescription
                )
                
                if !testCase.shouldSucceed {
                    throw TestFailure("Expected error for invalid update")
                }
                
                // Verify updated tag
                let tags = try manager.getAllTags()
                let updatedTag = tags.first { $0.id == tag.id }
                #expect(updatedTag?.name == testCase.newName)
                #expect(updatedTag?.description == testCase.newDescription)
                
                // Verify notification
                let notifications = context.notificationCenter.postedNotifications
                #expect(notifications.contains { notification in
                    notification.name == .tagUpdated &&
                    (notification.object as? BackupTag)?.id == tag.id
                })
                
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected error: \(error)")
                }
                
                if let error = error as? BackupTagError {
                    #expect(error == testCase.expectedError)
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Tag Association Tests
    
    @Test("Test tag associations", ["tag", "association"] as! TestTrait)
    func testTagAssociations() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // When/Then: Test tag associations
        for testCase in MockData.Tag.associationTags {
            do {
                let tag = try manager.createTag(name: testCase.name)
                try manager.associateTag(tag, withBackupId: testCase.backupId)
                
                if !testCase.shouldSucceed {
                    throw TestFailure("Expected error for invalid association")
                }
                
                // Verify association
                let tags = try manager.getTags(forBackupId: testCase.backupId)
                #expect(tags.contains(where: { $0.id == tag.id }))
                
                // Verify notification
                let notifications = context.notificationCenter.postedNotifications
                #expect(notifications.contains { notification in
                    notification.name == .tagAssociated &&
                    (notification.object as? (BackupTag, String))?.0.id == tag.id &&
                    (notification.object as? (BackupTag, String))?.1 == testCase.backupId
                })
                
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected error: \(error)")
                }
                
                if let error = error as? BackupTagError {
                    #expect(error == testCase.expectedError)
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Tag Deletion Tests
    
    @Test("Test tag deletion", ["tag", "delete"] as! TestTrait)
    func testTagDeletion() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // When/Then: Test tag deletion
        for testCase in MockData.Tag.basicTags {
            do {
                // Create tag
                let tag = try manager.createTag(
                    name: testCase.name,
                    description: testCase.description
                )
                
                // Delete tag
                try manager.deleteTag(tag)
                
                // Verify deletion
                let remaining = try manager.getAllTags()
                #expect(!remaining.contains(where: { $0.id == tag.id }))
                
                // Verify notification
                let notifications = context.notificationCenter.postedNotifications
                #expect(notifications.contains { notification in
                    notification.name == .tagDeleted &&
                    (notification.object as? BackupTag)?.id == tag.id
                })
                
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected error: \(error)")
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Tag Validation Tests
    
    @Test("Test tag validation", ["tag", "validation"] as! TestTrait)
    func testValidation() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Test invalid tag name
        do {
            try manager.createTag(name: "", description: nil)
            throw TestFailure("Expected error for empty tag name")
        } catch let error as BackupTagError {
            #expect(error == .invalidName)
        }
        
        // Test valid tag name
        do {
            let tag = try manager.createTag(name: "valid-tag")
            #expect(tag.name == "valid-tag")
        } catch {
            throw TestFailure("Unexpected error: \(error)")
        }
        
        // Test duplicate tag name
        do {
            try manager.createTag(name: "duplicate")
            try manager.createTag(name: "duplicate")
            throw TestFailure("Expected error for duplicate tag name")
        } catch let error as BackupTagError {
            #expect(error == .invalidName)
        }
    }
    
    // MARK: - Tag Listing Tests
    
    @Test("Test tag listing", ["tag", "list"] as! TestTrait)
    func testTagListing() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Create test tags
        let tag1 = try manager.createTag(name: "test1", description: "First test tag")
        let tag2 = try manager.createTag(name: "test2", description: "Second test tag")
        
        // Get all tags
        let tags = try manager.getAllTags()
        #expect(tags.count == 2)
        #expect(tags.contains(where: { $0.id == tag1.id }))
        #expect(tags.contains(where: { $0.id == tag2.id }))
        
        // Delete a tag
        try manager.deleteTag(tag1)
        let remainingTags = try manager.getAllTags()
        #expect(remainingTags.count == 1)
        #expect(remainingTags.contains(where: { $0.id == tag2.id }))
        
        // Verify notification
        let notifications = (context.notificationCenter as! TestMocks.MockNotificationCenter).postedNotifications
        #expect(notifications.contains { notification in
            notification.name == .tagDeleted &&
            (notification.object as? BackupTag)?.id == tag1.id
        })
    }
    
    // MARK: - Tag Update Tests
    
    @Test("Test tag updates", ["tag", "update"] as! TestTrait)
    func testTagUpdates() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Create and update tag
        let tag = try manager.createTag(name: "original", description: "Original description")
        try manager.updateTag(tag, name: "updated", description: "Updated description")
        
        // Verify update
        let tags = try manager.getAllTags()
        let updatedTag = tags.first { $0.id == tag.id }
        #expect(updatedTag?.name == "updated")
        #expect(updatedTag?.description == "Updated description")
        
        // Verify notification
        let notifications = (context.notificationCenter as! TestMocks.MockNotificationCenter).postedNotifications
        #expect(notifications.contains { notification in
            notification.name == .tagUpdated &&
            (notification.object as? BackupTag)?.id == tag.id
        })
    }
    
    // MARK: - Tag Deletion Tests
    
    @Test("Test tag deletion", ["tag", "delete"] as! TestTrait)
    func testTagDeletion() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Create and delete tag
        let tag = try manager.createTag(name: "to-delete")
        try manager.deleteTag(tag)
        
        // Verify deletion
        let remaining = try manager.getAllTags()
        #expect(!remaining.contains(where: { $0.id == tag.id }))
        
        // Verify notification
        let notifications = (context.notificationCenter as! TestMocks.MockNotificationCenter).postedNotifications
        #expect(notifications.contains { notification in
            notification.name == .tagDeleted &&
            (notification.object as? BackupTag)?.id == tag.id
        })
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test tag error handling", ["tag", "error"] as! TestTrait)
    func testErrorHandling() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Test invalid tag name
        do {
            try manager.createTag(name: "", description: nil)
            throw TestFailure("Expected error for empty tag name")
        } catch let error as BackupTagError {
            #expect(error == .invalidName)
        }
        
        // Test duplicate tag name
        do {
            let tag = try manager.createTag(name: "test")
            try manager.createTag(name: "test")
            throw TestFailure("Expected error for duplicate tag name")
        } catch let error as BackupTagError {
            #expect(error == .invalidName)
        }
        
        // Test deleting non-existent tag
        do {
            let tag = BackupTag(name: "non-existent")
            try manager.deleteTag(tag)
            throw TestFailure("Expected error for non-existent tag")
        } catch let error as BackupTagError {
            #expect(error == .tagNotFound)
        }
        
        // Test updating non-existent tag
        do {
            let tag = BackupTag(name: "non-existent")
            try manager.updateTag(tag, name: "new-name", description: nil)
            throw TestFailure("Expected error for non-existent tag")
        } catch let error as BackupTagError {
            #expect(error == .tagNotFound)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle tag edge cases", ["tag", "edge"] as! TestTrait)
    func testEdgeCases() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Test invalid tag name
        do {
            try manager.createTag(name: "", description: nil)
            throw TestFailure("Expected error for invalid tag name")
        } catch {
            // Expected error
        }
        
        // Test duplicate tag name
        do {
            let tag = try manager.createTag(name: "test")
            try manager.createTag(name: "test")
            throw TestFailure("Expected error for duplicate tag name")
        } catch {
            // Expected error
        }
        
        // Test empty tag list
        do {
            let tags = try manager.getAllTags()
            #expect(tags.isEmpty)
        } catch {
            throw TestFailure("Unexpected error for empty tag list")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test tag performance", ["tag", "performance"] as! TestTrait)
    func testPerformance() throws {
        // Given: Tag manager
        let context = TestContext()
        let manager = context.createTagManager()
        
        // Test listing performance
        let startTime = context.dateProvider.now
        
        for _ in 0..<100 {
            _ = try manager.getAllTags()
        }
        
        let endTime = context.dateProvider.now
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test tag creation performance
        let creationStartTime = context.dateProvider.now
        
        for i in 0..<1000 {
            _ = try manager.createTag(name: "test\(i)")
        }
        
        let creationEndTime = context.dateProvider.now
        
        let creationInterval = creationEndTime.timeIntervalSince(creationStartTime)
        #expect(creationInterval < 0.5) // Creation should be fast
    }
}
