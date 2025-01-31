//
//  BackupSourceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupSourceTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup source with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let name = "Documents"
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        
        // When
        let source = BackupSource(
            id: id,
            name: name,
            path: path
        )
        
        // Then
        #expect(source.id == id)
        #expect(source.name == name)
        #expect(source.path == path)
        #expect(source.excludePatterns.isEmpty)
        #expect(source.includePatterns.isEmpty)
        #expect(source.status == .unknown)
    }
    
    @Test("Initialize backup source with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let name = "Documents"
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        let excludePatterns = ["*.tmp", "*.cache"]
        let includePatterns = ["*.doc", "*.pdf"]
        let status = BackupSourceStatus.ready
        
        // When
        let source = BackupSource(
            id: id,
            name: name,
            path: path,
            excludePatterns: excludePatterns,
            includePatterns: includePatterns,
            status: status
        )
        
        // Then
        #expect(source.id == id)
        #expect(source.name == name)
        #expect(source.path == path)
        #expect(source.excludePatterns == excludePatterns)
        #expect(source.includePatterns == includePatterns)
        #expect(source.status == status)
    }
    
    // MARK: - Pattern Tests
    
    @Test("Handle include and exclude patterns", tags: ["model", "patterns"])
    func testPatterns() throws {
        let testCases = [
            // Basic patterns
            (["*.txt"], ["*.tmp"], true),
            // Multiple patterns
            (["*.doc", "*.pdf"], ["*.tmp", "*.cache"], true),
            // Complex patterns
            (["**/*.swift", "src/**/*.h"], ["**/build/*", "**/tmp/*"], true),
            // Invalid patterns
            (["[invalid"], ["[also-invalid"], false),
            // Empty patterns
            ([], [], true),
            // Overlapping patterns
            (["*.txt"], ["*.txt"], false),
            // Case sensitivity
            (["*.TXT", "*.txt"], ["*.TMP", "*.tmp"], false)
        ]
        
        for (include, exclude, isValid) in testCases {
            let source = BackupSource(
                id: UUID(),
                name: "Test",
                path: URL(fileURLWithPath: "/test"),
                excludePatterns: exclude,
                includePatterns: include
            )
            
            if isValid {
                #expect(source.isValid)
                #expect(source.includePatterns == include)
                #expect(source.excludePatterns == exclude)
            } else {
                #expect(!source.isValid)
            }
        }
    }
    
    // MARK: - Status Tests
    
    @Test("Handle backup source status changes", tags: ["model", "status"])
    func testStatusChanges() throws {
        let testCases: [(BackupSourceStatus, String)] = [
            (.unknown, "Unknown"),
            (.scanning, "Scanning"),
            (.ready, "Ready"),
            (.backing_up, "Backing Up"),
            (.error("test error"), "Error: test error")
        ]
        
        for (status, description) in testCases {
            let source = BackupSource(
                id: UUID(),
                name: "Test",
                path: URL(fileURLWithPath: "/test"),
                status: status
            )
            
            #expect(source.status == status)
            #expect(source.status.description == description)
        }
    }
    
    // MARK: - Path Tests
    
    @Test("Handle backup source paths", tags: ["model", "path"])
    func testSourcePaths() throws {
        let testCases = [
            // Standard paths
            "/Users/test/Documents",
            "/Applications",
            "/Library/Preferences",
            // Paths with spaces
            "/Users/test/My Documents",
            "/Volumes/Backup Drive/Data",
            // Paths with special characters
            "/Users/test/Documents!@#$%",
            // Very long paths
            "/Users/test/" + String(repeating: "a", count: 1000),
            // Home directory paths
            "~/Documents",
            "~/Library/Application Support",
            // Network paths
            "/Volumes/NetworkShare/Data",
            // Invalid paths
            "invalid://path",
            ""
        ]
        
        for pathString in testCases {
            let path = URL(string: pathString) ?? URL(fileURLWithPath: pathString)
            let source = BackupSource(
                id: UUID(),
                name: "Test",
                path: path
            )
            
            let isValidPath = path.isFileURL && !pathString.isEmpty
            if isValidPath {
                #expect(source.isValid)
                #expect(source.path == path)
            } else {
                #expect(!source.isValid)
            }
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup sources for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let source1 = BackupSource(
            id: UUID(),
            name: "Test 1",
            path: URL(fileURLWithPath: "/test/1")
        )
        
        let source2 = BackupSource(
            id: source1.id,
            name: "Test 1",
            path: URL(fileURLWithPath: "/test/1")
        )
        
        let source3 = BackupSource(
            id: UUID(),
            name: "Test 1",
            path: URL(fileURLWithPath: "/test/1")
        )
        
        #expect(source1 == source2)
        #expect(source1 != source3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup source", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic source
            BackupSource(
                id: UUID(),
                name: "Basic Source",
                path: URL(fileURLWithPath: "/basic/path")
            ),
            // Source with patterns
            BackupSource(
                id: UUID(),
                name: "Pattern Source",
                path: URL(fileURLWithPath: "/pattern/path"),
                excludePatterns: ["*.tmp", "*.cache"],
                includePatterns: ["*.doc", "*.pdf"]
            ),
            // Source with status
            BackupSource(
                id: UUID(),
                name: "Status Source",
                path: URL(fileURLWithPath: "/status/path"),
                status: .error("test error")
            )
        ]
        
        for source in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(BackupSource.self, from: data)
            
            // Then
            #expect(decoded.id == source.id)
            #expect(decoded.name == source.name)
            #expect(decoded.path == source.path)
            #expect(decoded.excludePatterns == source.excludePatterns)
            #expect(decoded.includePatterns == source.includePatterns)
            #expect(decoded.status == source.status)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup source properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Empty name
            ("", URL(fileURLWithPath: "/test"), [], [], false),
            // Name with only spaces
            ("   ", URL(fileURLWithPath: "/test"), [], [], false),
            // Valid name
            ("Test Source", URL(fileURLWithPath: "/test"), [], [], true),
            // Name with special characters
            ("Test!@#$%^&*()", URL(fileURLWithPath: "/test"), [], [], true),
            // Very long name
            (String(repeating: "a", count: 1000), URL(fileURLWithPath: "/test"), [], [], false),
            // Invalid path
            ("Test", URL(string: "invalid://path")!, [], [], false),
            // Valid path with patterns
            ("Test", URL(fileURLWithPath: "/test"), ["*.tmp"], ["*.doc"], true),
            // Invalid patterns
            ("Test", URL(fileURLWithPath: "/test"), ["[invalid"], ["[also-invalid"], false)
        ]
        
        for (name, path, exclude, include, isValid) in testCases {
            let source = BackupSource(
                id: UUID(),
                name: name,
                path: path,
                excludePatterns: exclude,
                includePatterns: include
            )
            
            if isValid {
                #expect(source.isValid)
            } else {
                #expect(!source.isValid)
            }
        }
    }
}
