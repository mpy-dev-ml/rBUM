//
//  BackupTagTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupTagTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup tag with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let name = "daily-backup"
        
        // When
        let tag = BackupTag(
            id: id,
            name: name
        )
        
        // Then
        #expect(tag.id == id)
        #expect(tag.name == name)
        #expect(tag.description.isEmpty)
        #expect(tag.colour == nil)
        #expect(tag.createdAt.timeIntervalSinceNow <= 0)
    }
    
    @Test("Initialize backup tag with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let name = "daily-backup"
        let description = "Daily backup tag"
        let colour = TagColour.blue
        let createdAt = Date(timeIntervalSinceNow: -3600)
        
        // When
        let tag = BackupTag(
            id: id,
            name: name,
            description: description,
            colour: colour,
            createdAt: createdAt
        )
        
        // Then
        #expect(tag.id == id)
        #expect(tag.name == name)
        #expect(tag.description == description)
        #expect(tag.colour == colour)
        #expect(tag.createdAt == createdAt)
    }
    
    // MARK: - Name Tests
    
    @Test("Handle tag name formats", tags: ["model", "name"])
    func testNameFormats() throws {
        let testCases = [
            // Valid names
            "daily-backup",
            "weekly_backup",
            "monthly.backup",
            "backup2024",
            "critical-files",
            // Invalid names
            "",
            " ",
            "invalid tag",
            "invalid/tag",
            "invalid\\tag",
            String(repeating: "a", count: 1000)
        ]
        
        for name in testCases {
            let tag = BackupTag(
                id: UUID(),
                name: name
            )
            
            let isValid = !name.isEmpty &&
                         !name.contains(" ") &&
                         !name.contains("/") &&
                         !name.contains("\\") &&
                         name.count <= 100
            
            if isValid {
                #expect(tag.isValid)
                #expect(tag.name == name)
            } else {
                #expect(!tag.isValid)
            }
        }
    }
    
    // MARK: - Colour Tests
    
    @Test("Handle tag colours", tags: ["model", "colour"])
    func testColours() throws {
        let testCases: [(TagColour, String)] = [
            (.red, "Red"),
            (.blue, "Blue"),
            (.green, "Green"),
            (.yellow, "Yellow"),
            (.purple, "Purple"),
            (.orange, "Orange"),
            (.grey, "Grey")
        ]
        
        for (colour, description) in testCases {
            let tag = BackupTag(
                id: UUID(),
                name: "test",
                colour: colour
            )
            
            #expect(tag.colour == colour)
            #expect(tag.colour?.description == description)
        }
    }
    
    // MARK: - Description Tests
    
    @Test("Handle tag descriptions", tags: ["model", "description"])
    func testDescriptions() throws {
        let testCases = [
            // Valid descriptions
            "Daily backup tag",
            "This tag is used for critical system files",
            String(repeating: "a", count: 500),
            // Empty description
            "",
            // Description with special characters
            "Tag description with !@#$%^&*()",
            // Description with newlines
            "First line\nSecond line",
            // Description with tabs
            "Description\twith\ttabs"
        ]
        
        for description in testCases {
            let tag = BackupTag(
                id: UUID(),
                name: "test",
                description: description
            )
            
            let isValid = description.count <= 1000
            if isValid {
                #expect(tag.isValid)
                #expect(tag.description == description)
            } else {
                #expect(!tag.isValid)
            }
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup tags for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let tag1 = BackupTag(
            id: UUID(),
            name: "test1",
            description: "Test tag 1",
            colour: .blue
        )
        
        let tag2 = BackupTag(
            id: tag1.id,
            name: "test1",
            description: "Test tag 1",
            colour: .blue
        )
        
        let tag3 = BackupTag(
            id: UUID(),
            name: "test1",
            description: "Test tag 1",
            colour: .blue
        )
        
        #expect(tag1 == tag2)
        #expect(tag1 != tag3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup tag", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic tag
            BackupTag(
                id: UUID(),
                name: "basic-tag"
            ),
            // Tag with description
            BackupTag(
                id: UUID(),
                name: "desc-tag",
                description: "Tag with description"
            ),
            // Tag with colour
            BackupTag(
                id: UUID(),
                name: "colour-tag",
                colour: .blue
            ),
            // Full tag
            BackupTag(
                id: UUID(),
                name: "full-tag",
                description: "Full tag with all properties",
                colour: .red,
                createdAt: Date(timeIntervalSinceNow: -3600)
            )
        ]
        
        for tag in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(tag)
            let decoded = try decoder.decode(BackupTag.self, from: data)
            
            // Then
            #expect(decoded.id == tag.id)
            #expect(decoded.name == tag.name)
            #expect(decoded.description == tag.description)
            #expect(decoded.colour == tag.colour)
            #expect(decoded.createdAt == tag.createdAt)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup tag properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid tag
            ("valid-tag", "Valid description", .blue, true),
            // Empty name
            ("", "Description", .blue, false),
            // Name with spaces
            ("invalid tag", "Description", .blue, false),
            // Name with special characters
            ("invalid/tag", "Description", .blue, false),
            // Very long name
            (String(repeating: "a", count: 1000), "Description", .blue, false),
            // Very long description
            ("valid-tag", String(repeating: "a", count: 2000), .blue, false)
        ]
        
        for (name, description, colour, isValid) in testCases {
            let tag = BackupTag(
                id: UUID(),
                name: name,
                description: description,
                colour: colour
            )
            
            if isValid {
                #expect(tag.isValid)
            } else {
                #expect(!tag.isValid)
            }
        }
    }
}
