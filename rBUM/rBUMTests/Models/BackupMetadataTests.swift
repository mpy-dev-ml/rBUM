//
//  BackupMetadataTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupMetadata functionality
struct BackupMetadataTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        let dateProvider: MockDateProvider
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
            self.dateProvider = MockDateProvider()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
            dateProvider.reset()
        }
        
        /// Create test metadata
        func createMetadata() -> BackupMetadata {
            BackupMetadata(
                userDefaults: userDefaults,
                fileManager: fileManager,
                dateProvider: dateProvider
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize backup metadata", tags: ["init", "metadata"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating metadata
        let metadata = context.createMetadata()
        
        // Then: Metadata is properly initialized
        #expect(metadata.backupCount == 0)
        #expect(!metadata.isLoading)
        #expect(!metadata.showError)
        #expect(metadata.error == nil)
    }
    
    // MARK: - Tag Management Tests
    
    @Test("Test tag management", tags: ["tag", "metadata"])
    func testTagManagement() throws {
        // Given: Metadata and test data
        let context = TestContext()
        let metadata = context.createMetadata()
        
        let tags = MockData.Tag.validTags
        
        // When: Adding tags
        for tag in tags {
            metadata.addTag(tag)
        }
        
        // Then: Tags are stored
        #expect(metadata.tags.count == tags.count)
        for tag in tags {
            #expect(metadata.hasTag(tag))
        }
        
        // When: Removing tag
        metadata.removeTag(tags[0])
        
        // Then: Tag is removed
        #expect(!metadata.hasTag(tags[0]))
        #expect(metadata.tags.count == tags.count - 1)
    }
    
    // MARK: - Label Management Tests
    
    @Test("Test label management", tags: ["label", "metadata"])
    func testLabelManagement() throws {
        // Given: Metadata and test data
        let context = TestContext()
        let metadata = context.createMetadata()
        
        let labels = MockData.Label.validLabels
        
        // When: Adding labels
        for (key, value) in labels {
            metadata.setLabel(key: key, value: value)
        }
        
        // Then: Labels are stored
        #expect(metadata.labels.count == labels.count)
        for (key, value) in labels {
            #expect(metadata.getLabel(key: key) == value)
        }
        
        // When: Removing label
        let firstKey = labels.keys.first!
        metadata.removeLabel(key: firstKey)
        
        // Then: Label is removed
        #expect(metadata.getLabel(key: firstKey) == nil)
        #expect(metadata.labels.count == labels.count - 1)
    }
    
    // MARK: - Annotation Management Tests
    
    @Test("Test annotation management", tags: ["annotation", "metadata"])
    func testAnnotationManagement() throws {
        // Given: Metadata and test data
        let context = TestContext()
        let metadata = context.createMetadata()
        
        let annotations = MockData.Annotation.validAnnotations
        
        // When: Adding annotations
        for (key, value) in annotations {
            metadata.setAnnotation(key: key, value: value)
        }
        
        // Then: Annotations are stored
        #expect(metadata.annotations.count == annotations.count)
        for (key, value) in annotations {
            #expect(metadata.getAnnotation(key: key) == value)
        }
        
        // When: Removing annotation
        let firstKey = annotations.keys.first!
        metadata.removeAnnotation(key: firstKey)
        
        // Then: Annotation is removed
        #expect(metadata.getAnnotation(key: firstKey) == nil)
        #expect(metadata.annotations.count == annotations.count - 1)
    }
    
    // MARK: - Storage Tests
    
    @Test("Store and retrieve backup metadata", tags: ["storage", "metadata"])
    func testMetadataStorage() throws {
        // Given: Metadata with test data
        let context = TestContext()
        let metadata = context.createMetadata()
        let testBackup = MockData.Backup.validBackup
        
        // When: Storing backup metadata
        metadata.store(backup: testBackup)
        
        // Then: Metadata is stored correctly
        #expect(metadata.backupCount == 1)
        #expect(metadata.getBackup(id: testBackup.id) == testBackup)
        #expect(!metadata.isLoading)
        #expect(!metadata.showError)
    }
    
    @Test("Update backup metadata", tags: ["update", "metadata"])
    func testMetadataUpdate() throws {
        // Given: Metadata with stored backup
        let context = TestContext()
        let metadata = context.createMetadata()
        var testBackup = MockData.Backup.validBackup
        metadata.store(backup: testBackup)
        
        // When: Updating backup metadata
        testBackup.name = "Updated Name"
        metadata.update(backup: testBackup)
        
        // Then: Metadata is updated correctly
        #expect(metadata.getBackup(id: testBackup.id)?.name == "Updated Name")
        #expect(!metadata.isLoading)
        #expect(!metadata.showError)
    }
    
    @Test("Delete backup metadata", tags: ["delete", "metadata"])
    func testMetadataDeletion() throws {
        // Given: Metadata with stored backup
        let context = TestContext()
        let metadata = context.createMetadata()
        let testBackup = MockData.Backup.validBackup
        metadata.store(backup: testBackup)
        
        // When: Deleting backup metadata
        metadata.delete(id: testBackup.id)
        
        // Then: Metadata is deleted correctly
        #expect(metadata.backupCount == 0)
        #expect(metadata.getBackup(id: testBackup.id) == nil)
        #expect(!metadata.isLoading)
        #expect(!metadata.showError)
    }
    
    // MARK: - Persistence Tests
    
    @Test("Handle metadata persistence", tags: ["persistence", "metadata"])
    func testPersistence() throws {
        // Given: Metadata with test data
        let context = TestContext()
        let metadata = context.createMetadata()
        let testBackups = MockData.Backup.validBackups
        
        // When: Storing multiple backups
        for backup in testBackups {
            metadata.store(backup: backup)
        }
        
        // Then: Metadata is persisted correctly
        #expect(metadata.backupCount == testBackups.count)
        for backup in testBackups {
            #expect(metadata.getBackup(id: backup.id) == backup)
        }
        #expect(context.userDefaults.saveCalled)
    }
    
    // MARK: - Search Tests
    
    @Test("Test metadata search", tags: ["search", "metadata"])
    func testSearch() throws {
        // Given: Metadata with test data
        let context = TestContext()
        let metadata = context.createMetadata()
        
        let tags = MockData.Tag.validTags
        let labels = MockData.Label.validLabels
        let annotations = MockData.Annotation.validAnnotations
        
        // Add test data
        for tag in tags {
            metadata.addTag(tag)
        }
        for (key, value) in labels {
            metadata.setLabel(key: key, value: value)
        }
        for (key, value) in annotations {
            metadata.setAnnotation(key: key, value: value)
        }
        
        // Test searching by tag
        let tagResults = metadata.search(query: tags[0])
        #expect(tagResults.contains(tags[0]))
        
        // Test searching by label
        let labelKey = labels.keys.first!
        let labelResults = metadata.search(query: labels[labelKey]!)
        #expect(!labelResults.isEmpty)
        
        // Test searching by annotation
        let annotationKey = annotations.keys.first!
        let annotationResults = metadata.search(query: annotations[annotationKey]!)
        #expect(!annotationResults.isEmpty)
        
        // Test searching with no results
        let noResults = metadata.search(query: "nonexistent")
        #expect(noResults.isEmpty)
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle metadata edge cases", tags: ["edge", "metadata"])
    func testEdgeCases() throws {
        // Given: Metadata
        let context = TestContext()
        let metadata = context.createMetadata()
        
        // Test empty tag
        metadata.addTag("")
        #expect(!metadata.hasTag(""))
        
        // Test duplicate tag
        let tag = MockData.Tag.validTags[0]
        metadata.addTag(tag)
        metadata.addTag(tag)
        #expect(metadata.tags.count == 1)
        
        // Test empty label key
        metadata.setLabel(key: "", value: "value")
        #expect(metadata.getLabel(key: "") == nil)
        
        // Test empty label value
        metadata.setLabel(key: "key", value: "")
        #expect(metadata.getLabel(key: "key") == nil)
        
        // Test empty annotation key
        metadata.setAnnotation(key: "", value: "value")
        #expect(metadata.getAnnotation(key: "") == nil)
        
        // Test empty annotation value
        metadata.setAnnotation(key: "key", value: "")
        #expect(metadata.getAnnotation(key: "key") == nil)
        
        // Test load without save
        let emptyMetadata = context.createMetadata()
        try emptyMetadata.load()
        #expect(emptyMetadata.tags.isEmpty)
        #expect(emptyMetadata.labels.isEmpty)
        #expect(emptyMetadata.annotations.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test metadata performance", tags: ["performance", "metadata"])
    func testPerformance() throws {
        // Given: Metadata
        let context = TestContext()
        let metadata = context.createMetadata()
        
        // Test bulk tag addition
        let startTime = context.dateProvider.now()
        for i in 0..<1000 {
            metadata.addTag("tag\(i)")
        }
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test search performance
        let searchStartTime = context.dateProvider.now()
        _ = metadata.search(query: "tag500")
        let searchEndTime = context.dateProvider.now()
        
        let searchInterval = searchEndTime.timeIntervalSince(searchStartTime)
        #expect(searchInterval < 0.1) // Search should be fast
    }
}
