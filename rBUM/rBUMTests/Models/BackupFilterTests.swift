//
//  BackupFilterTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupFilterTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup filter with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let pattern = "*.tmp"
        let type = BackupFilterType.exclude
        
        // When
        let filter = BackupFilter(
            id: id,
            pattern: pattern,
            type: type
        )
        
        // Then
        #expect(filter.id == id)
        #expect(filter.pattern == pattern)
        #expect(filter.type == type)
        #expect(filter.description.isEmpty)
        #expect(filter.isEnabled)
    }
    
    @Test("Initialize backup filter with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let pattern = "*.tmp"
        let type = BackupFilterType.exclude
        let description = "Exclude temporary files"
        let isEnabled = false
        
        // When
        let filter = BackupFilter(
            id: id,
            pattern: pattern,
            type: type,
            description: description,
            isEnabled: isEnabled
        )
        
        // Then
        #expect(filter.id == id)
        #expect(filter.pattern == pattern)
        #expect(filter.type == type)
        #expect(filter.description == description)
        #expect(filter.isEnabled == isEnabled)
    }
    
    // MARK: - Pattern Tests
    
    @Test("Handle filter patterns", tags: ["model", "pattern"])
    func testPatterns() throws {
        let testCases = [
            // Simple patterns
            "*.tmp",
            "*.log",
            "*.cache",
            // Directory patterns
            "**/build/*",
            "**/node_modules/**",
            "**/tmp/**/*",
            // Complex patterns
            "**/*.{tmp,log,cache}",
            "[0-9]*.bak",
            "backup-????-??-??",
            // Invalid patterns
            "",
            " ",
            "[invalid",
            String(repeating: "a", count: 1000)
        ]
        
        for pattern in testCases {
            let filter = BackupFilter(
                id: UUID(),
                pattern: pattern,
                type: .exclude
            )
            
            let isValid = !pattern.isEmpty &&
                         pattern.trimmingCharacters(in: .whitespaces) == pattern &&
                         pattern.count <= 500
            
            if isValid {
                #expect(filter.isValid)
                #expect(filter.pattern == pattern)
            } else {
                #expect(!filter.isValid)
            }
        }
    }
    
    // MARK: - Type Tests
    
    @Test("Handle filter types", tags: ["model", "type"])
    func testFilterTypes() throws {
        let testCases: [(BackupFilterType, String)] = [
            (.include, "Include"),
            (.exclude, "Exclude")
        ]
        
        for (type, description) in testCases {
            let filter = BackupFilter(
                id: UUID(),
                pattern: "*.tmp",
                type: type
            )
            
            #expect(filter.type == type)
            #expect(filter.type.description == description)
        }
    }
    
    // MARK: - Pattern Matching Tests
    
    @Test("Test pattern matching", tags: ["model", "matching"])
    func testPatternMatching() throws {
        let testCases = [
            // Simple file matches
            ("*.tmp", "file.tmp", true),
            ("*.log", "system.log", true),
            ("*.tmp", "file.log", false),
            // Directory matches
            ("**/build/*", "project/build/output.txt", true),
            ("**/build/*", "project/src/file.txt", false),
            // Multiple extensions
            ("*.{tmp,log}", "file.tmp", true),
            ("*.{tmp,log}", "file.log", true),
            ("*.{tmp,log}", "file.txt", false),
            // Wildcards
            ("backup-????-??-??", "backup-2024-01-30", true),
            ("backup-????-??-??", "backup-invalid", false),
            // Case sensitivity
            ("*.TMP", "file.tmp", true),
            ("*.tmp", "file.TMP", true)
        ]
        
        for (pattern, path, shouldMatch) in testCases {
            let filter = BackupFilter(
                id: UUID(),
                pattern: pattern,
                type: .exclude
            )
            
            #expect(filter.matches(path: path) == shouldMatch)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup filters for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let filter1 = BackupFilter(
            id: UUID(),
            pattern: "*.tmp",
            type: .exclude,
            description: "Test filter"
        )
        
        let filter2 = BackupFilter(
            id: filter1.id,
            pattern: "*.tmp",
            type: .exclude,
            description: "Test filter"
        )
        
        let filter3 = BackupFilter(
            id: UUID(),
            pattern: "*.tmp",
            type: .exclude,
            description: "Test filter"
        )
        
        #expect(filter1 == filter2)
        #expect(filter1 != filter3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup filter", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic filter
            BackupFilter(
                id: UUID(),
                pattern: "*.tmp",
                type: .exclude
            ),
            // Filter with description
            BackupFilter(
                id: UUID(),
                pattern: "*.log",
                type: .include,
                description: "Include log files"
            ),
            // Disabled filter
            BackupFilter(
                id: UUID(),
                pattern: "*.cache",
                type: .exclude,
                isEnabled: false
            )
        ]
        
        for filter in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(filter)
            let decoded = try decoder.decode(BackupFilter.self, from: data)
            
            // Then
            #expect(decoded.id == filter.id)
            #expect(decoded.pattern == filter.pattern)
            #expect(decoded.type == filter.type)
            #expect(decoded.description == filter.description)
            #expect(decoded.isEnabled == filter.isEnabled)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup filter properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid filter
            ("*.tmp", .exclude, "Valid description", true, true),
            // Empty pattern
            ("", .exclude, "Description", true, false),
            // Pattern with only spaces
            ("   ", .include, "Description", true, false),
            // Very long pattern
            (String(repeating: "a", count: 1000), .exclude, "Description", true, false),
            // Very long description
            ("*.tmp", .exclude, String(repeating: "a", count: 2000), true, false),
            // Invalid pattern syntax
            ("[invalid", .exclude, "Description", true, false)
        ]
        
        for (pattern, type, description, isEnabled, isValid) in testCases {
            let filter = BackupFilter(
                id: UUID(),
                pattern: pattern,
                type: type,
                description: description,
                isEnabled: isEnabled
            )
            
            if isValid {
                #expect(filter.isValid)
            } else {
                #expect(!filter.isValid)
            }
        }
    }
}
