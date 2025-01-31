//
//  BackupNotificationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupNotificationTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup notification with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let title = "Backup Complete"
        let message = "Your backup has completed successfully"
        let type = NotificationType.success
        
        // When
        let notification = BackupNotification(
            id: id,
            title: title,
            message: message,
            type: type
        )
        
        // Then
        #expect(notification.id == id)
        #expect(notification.title == title)
        #expect(notification.message == message)
        #expect(notification.type == type)
        #expect(notification.createdAt.timeIntervalSinceNow <= 0)
        #expect(notification.isRead == false)
        #expect(notification.metadata.isEmpty)
    }
    
    @Test("Initialize backup notification with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let title = "Backup Complete"
        let message = "Your backup has completed successfully"
        let type = NotificationType.success
        let createdAt = Date(timeIntervalSinceNow: -3600)
        let isRead = true
        let metadata = ["repository": "test-repo", "size": "1.5 GB"]
        
        // When
        let notification = BackupNotification(
            id: id,
            title: title,
            message: message,
            type: type,
            createdAt: createdAt,
            isRead: isRead,
            metadata: metadata
        )
        
        // Then
        #expect(notification.id == id)
        #expect(notification.title == title)
        #expect(notification.message == message)
        #expect(notification.type == type)
        #expect(notification.createdAt == createdAt)
        #expect(notification.isRead == isRead)
        #expect(notification.metadata == metadata)
    }
    
    // MARK: - Type Tests
    
    @Test("Handle notification types", tags: ["model", "type"])
    func testNotificationTypes() throws {
        let testCases: [(NotificationType, String, Bool)] = [
            (.info, "Information", false),
            (.success, "Success", false),
            (.warning, "Warning", true),
            (.error, "Error", true),
            (.critical, "Critical", true)
        ]
        
        for (type, description, requiresAction) in testCases {
            let notification = BackupNotification(
                id: UUID(),
                title: "Test",
                message: "Test message",
                type: type
            )
            
            #expect(notification.type == type)
            #expect(notification.type.description == description)
            #expect(notification.type.requiresAction == requiresAction)
        }
    }
    
    // MARK: - Metadata Tests
    
    @Test("Handle notification metadata", tags: ["model", "metadata"])
    func testMetadata() throws {
        let testCases = [
            // Basic metadata
            ["repository": "test-repo"],
            // Multiple entries
            ["repository": "test-repo", "size": "1.5 GB", "duration": "5 minutes"],
            // Empty metadata
            [:],
            // Metadata with special characters
            ["path": "/test/path!@#$", "status": "completed!"],
            // Long values
            ["description": String(repeating: "a", count: 1000)]
        ]
        
        for metadata in testCases {
            let notification = BackupNotification(
                id: UUID(),
                title: "Test",
                message: "Test message",
                type: .info,
                metadata: metadata
            )
            
            let isValid = metadata.allSatisfy { $0.value.count <= 1000 }
            if isValid {
                #expect(notification.isValid)
                #expect(notification.metadata == metadata)
            } else {
                #expect(!notification.isValid)
            }
        }
    }
    
    // MARK: - Read Status Tests
    
    @Test("Handle read status changes", tags: ["model", "status"])
    func testReadStatus() throws {
        // Given
        var notification = BackupNotification(
            id: UUID(),
            title: "Test",
            message: "Test message",
            type: .info
        )
        
        // Then - Initial state
        #expect(!notification.isRead)
        
        // When - Mark as read
        notification.isRead = true
        #expect(notification.isRead)
        
        // When - Mark as unread
        notification.isRead = false
        #expect(!notification.isRead)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup notifications for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let notification1 = BackupNotification(
            id: UUID(),
            title: "Test 1",
            message: "Test message 1",
            type: .info
        )
        
        let notification2 = BackupNotification(
            id: notification1.id,
            title: "Test 1",
            message: "Test message 1",
            type: .info
        )
        
        let notification3 = BackupNotification(
            id: UUID(),
            title: "Test 1",
            message: "Test message 1",
            type: .info
        )
        
        #expect(notification1 == notification2)
        #expect(notification1 != notification3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup notification", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic notification
            BackupNotification(
                id: UUID(),
                title: "Basic",
                message: "Basic message",
                type: .info
            ),
            // Notification with metadata
            BackupNotification(
                id: UUID(),
                title: "With Metadata",
                message: "Message with metadata",
                type: .success,
                metadata: ["key": "value"]
            ),
            // Read notification
            BackupNotification(
                id: UUID(),
                title: "Read",
                message: "Read message",
                type: .warning,
                isRead: true
            ),
            // Full notification
            BackupNotification(
                id: UUID(),
                title: "Full",
                message: "Full message",
                type: .error,
                createdAt: Date(timeIntervalSinceNow: -3600),
                isRead: true,
                metadata: ["key1": "value1", "key2": "value2"]
            )
        ]
        
        for notification in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(notification)
            let decoded = try decoder.decode(BackupNotification.self, from: data)
            
            // Then
            #expect(decoded.id == notification.id)
            #expect(decoded.title == notification.title)
            #expect(decoded.message == notification.message)
            #expect(decoded.type == notification.type)
            #expect(decoded.createdAt == notification.createdAt)
            #expect(decoded.isRead == notification.isRead)
            #expect(decoded.metadata == notification.metadata)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup notification properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid notification
            ("Valid Title", "Valid message", .info, [:], true),
            // Empty title
            ("", "Message", .info, [:], false),
            // Empty message
            ("Title", "", .info, [:], false),
            // Title with only spaces
            ("   ", "Message", .info, [:], false),
            // Message with only spaces
            ("Title", "   ", .info, [:], false),
            // Very long title
            (String(repeating: "a", count: 1000), "Message", .info, [:], false),
            // Very long message
            ("Title", String(repeating: "a", count: 10000), .info, [:], false),
            // Invalid metadata value
            ("Title", "Message", .info, ["key": String(repeating: "a", count: 2000)], false)
        ]
        
        for (title, message, type, metadata, isValid) in testCases {
            let notification = BackupNotification(
                id: UUID(),
                title: title,
                message: message,
                type: type,
                metadata: metadata
            )
            
            if isValid {
                #expect(notification.isValid)
            } else {
                #expect(!notification.isValid)
            }
        }
    }
}
