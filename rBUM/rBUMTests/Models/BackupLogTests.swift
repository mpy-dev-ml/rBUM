//
//  BackupLogTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupLogTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup log with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let operationId = UUID()
        let level = BackupLogLevel.info
        let message = "Test log message"
        let timestamp = Date()
        
        // When
        let log = BackupLog(
            id: id,
            operationId: operationId,
            level: level,
            message: message,
            timestamp: timestamp
        )
        
        // Then
        #expect(log.id == id)
        #expect(log.operationId == operationId)
        #expect(log.level == level)
        #expect(log.message == message)
        #expect(log.timestamp == timestamp)
        #expect(log.metadata.isEmpty)
    }
    
    @Test("Initialize backup log with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let operationId = UUID()
        let level = BackupLogLevel.error
        let message = "Test log message"
        let timestamp = Date()
        let metadata = ["key": "value", "error": "network timeout"]
        
        // When
        let log = BackupLog(
            id: id,
            operationId: operationId,
            level: level,
            message: message,
            timestamp: timestamp,
            metadata: metadata
        )
        
        // Then
        #expect(log.id == id)
        #expect(log.operationId == operationId)
        #expect(log.level == level)
        #expect(log.message == message)
        #expect(log.timestamp == timestamp)
        #expect(log.metadata == metadata)
    }
    
    // MARK: - Log Level Tests
    
    @Test("Handle log levels correctly", tags: ["model", "level"])
    func testLogLevels() throws {
        let testCases: [(BackupLogLevel, Bool)] = [
            (.debug, true),
            (.info, true),
            (.warning, true),
            (.error, true),
            (.critical, true)
        ]
        
        for (level, shouldLog) in testCases {
            let log = BackupLog(
                id: UUID(),
                operationId: UUID(),
                level: level,
                message: "Test message",
                timestamp: Date()
            )
            
            #expect(log.shouldLog(atLevel: level))
            #expect(log.shouldLog(atLevel: .critical) == (level == .critical))
            
            // Test level comparison
            #expect(level >= .debug)
            #expect(level <= .critical)
        }
    }
    
    // MARK: - Message Tests
    
    @Test("Handle message formatting", tags: ["model", "message"])
    func testMessageFormatting() throws {
        let testCases = [
            // Basic message
            ("Test message", [:]),
            // Message with metadata
            ("Error occurred", ["error": "network timeout"]),
            // Message with multiple metadata
            ("Operation completed", ["duration": "5s", "files": "100"])
        ]
        
        for (message, metadata) in testCases {
            let log = BackupLog(
                id: UUID(),
                operationId: UUID(),
                level: .info,
                message: message,
                timestamp: Date(),
                metadata: metadata
            )
            
            let formatted = log.formattedMessage
            #expect(formatted.contains(message))
            
            for (key, value) in metadata {
                #expect(formatted.contains(key))
                #expect(formatted.contains(value))
            }
        }
    }
    
    // MARK: - Timestamp Tests
    
    @Test("Handle timestamp formatting", tags: ["model", "timestamp"])
    func testTimestampFormatting() throws {
        // Given
        let timestamp = Date()
        let log = BackupLog(
            id: UUID(),
            operationId: UUID(),
            level: .info,
            message: "Test message",
            timestamp: timestamp
        )
        
        // When
        let formatted = log.formattedTimestamp
        
        // Then
        // Verify ISO8601 format
        let formatter = ISO8601DateFormatter()
        let parsedDate = formatter.date(from: formatted)
        #expect(parsedDate != nil)
        #expect(parsedDate?.timeIntervalSince1970 == timestamp.timeIntervalSince1970)
    }
    
    // MARK: - Metadata Tests
    
    @Test("Handle metadata operations", tags: ["model", "metadata"])
    func testMetadataOperations() throws {
        // Given
        var log = BackupLog(
            id: UUID(),
            operationId: UUID(),
            level: .info,
            message: "Test message",
            timestamp: Date()
        )
        
        // Test adding metadata
        log.addMetadata(key: "test", value: "value")
        #expect(log.metadata["test"] == "value")
        
        // Test updating metadata
        log.addMetadata(key: "test", value: "updated")
        #expect(log.metadata["test"] == "updated")
        
        // Test removing metadata
        log.removeMetadata(key: "test")
        #expect(log.metadata["test"] == nil)
        
        // Test clearing metadata
        log.addMetadata(key: "test1", value: "value1")
        log.addMetadata(key: "test2", value: "value2")
        log.clearMetadata()
        #expect(log.metadata.isEmpty)
    }
    
    // MARK: - Sensitive Data Tests
    
    @Test("Handle sensitive data in logs", tags: ["model", "security"])
    func testSensitiveDataHandling() throws {
        let testCases = [
            // Password in message
            "Password is: secret123",
            // API key in message
            "Using API key: sk_test_123456",
            // Token in message
            "Bearer token: eyJ0eXAiOiJKV1QiLCJhbGc",
            // Credentials in metadata
            "Error accessing with credentials user:pass"
        ]
        
        for message in testCases {
            let log = BackupLog(
                id: UUID(),
                operationId: UUID(),
                level: .error,
                message: message,
                timestamp: Date()
            )
            
            let formatted = log.formattedMessage
            
            // Verify sensitive data is redacted
            #expect(!formatted.contains("secret123"))
            #expect(!formatted.contains("sk_test_123456"))
            #expect(!formatted.contains("eyJ0eXAiOiJKV1QiLCJhbGc"))
            #expect(!formatted.contains("user:pass"))
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare logs for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let timestamp = Date()
        let log1 = BackupLog(
            id: UUID(),
            operationId: UUID(),
            level: .info,
            message: "Test message",
            timestamp: timestamp
        )
        
        let log2 = BackupLog(
            id: log1.id,
            operationId: log1.operationId,
            level: .info,
            message: "Test message",
            timestamp: timestamp
        )
        
        let log3 = BackupLog(
            id: UUID(),
            operationId: log1.operationId,
            level: .info,
            message: "Test message",
            timestamp: timestamp
        )
        
        #expect(log1 == log2)
        #expect(log1 != log3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup log", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic log
            BackupLog(
                id: UUID(),
                operationId: UUID(),
                level: .info,
                message: "Test message",
                timestamp: Date()
            ),
            // Log with metadata
            BackupLog(
                id: UUID(),
                operationId: UUID(),
                level: .error,
                message: "Error message",
                timestamp: Date(),
                metadata: ["error": "network timeout"]
            )
        ]
        
        for log in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(log)
            let decoded = try decoder.decode(BackupLog.self, from: data)
            
            // Then
            #expect(decoded.id == log.id)
            #expect(decoded.operationId == log.operationId)
            #expect(decoded.level == log.level)
            #expect(decoded.message == log.message)
            #expect(decoded.timestamp == log.timestamp)
            #expect(decoded.metadata == log.metadata)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup log properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid log
            (UUID(), UUID(), .info, "Test message", Date(), true),
            // Empty message
            (UUID(), UUID(), .info, "", Date(), false),
            // Future timestamp
            (UUID(), UUID(), .info, "Test message", Date(timeIntervalSinceNow: 3600), false)
        ]
        
        for (id, opId, level, message, timestamp, isValid) in testCases {
            let log = BackupLog(
                id: id,
                operationId: opId,
                level: level,
                message: message,
                timestamp: timestamp
            )
            
            if isValid {
                #expect(log.isValid)
            } else {
                #expect(!log.isValid)
            }
        }
    }
}
