//
//  BackupResticTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupResticTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup restic with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let path = URL(fileURLWithPath: "/usr/local/bin/restic")
        
        // When
        let restic = BackupRestic(
            id: id,
            repositoryId: repositoryId,
            executablePath: path
        )
        
        // Then
        #expect(restic.id == id)
        #expect(restic.repositoryId == repositoryId)
        #expect(restic.executablePath == path)
        #expect(restic.version != nil)
        #expect(restic.jsonOutput == true)
    }
    
    @Test("Initialize backup restic with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let path = URL(fileURLWithPath: "/usr/local/bin/restic")
        let version = "0.15.1"
        let jsonOutput = true
        let compressionLevel = 6
        let parallelOperations = 4
        
        // When
        let restic = BackupRestic(
            id: id,
            repositoryId: repositoryId,
            executablePath: path,
            version: version,
            jsonOutput: jsonOutput,
            compressionLevel: compressionLevel,
            parallelOperations: parallelOperations
        )
        
        // Then
        #expect(restic.id == id)
        #expect(restic.repositoryId == repositoryId)
        #expect(restic.executablePath == path)
        #expect(restic.version == version)
        #expect(restic.jsonOutput == jsonOutput)
        #expect(restic.compressionLevel == compressionLevel)
        #expect(restic.parallelOperations == parallelOperations)
    }
    
    // MARK: - Command Tests
    
    @Test("Handle restic commands", tags: ["model", "command"])
    func testCommands() throws {
        // Given
        let restic = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        // Test backup command
        let backupCmd = restic.buildCommand(
            .backup,
            args: ["--path", "/test/source"]
        )
        #expect(backupCmd.contains("backup"))
        #expect(backupCmd.contains("--json"))
        #expect(backupCmd.contains("/test/source"))
        
        // Test restore command
        let restoreCmd = restic.buildCommand(
            .restore,
            args: ["--target", "/test/restore"]
        )
        #expect(restoreCmd.contains("restore"))
        #expect(restoreCmd.contains("--json"))
        #expect(restoreCmd.contains("/test/restore"))
        
        // Test check command
        let checkCmd = restic.buildCommand(.check)
        #expect(checkCmd.contains("check"))
        #expect(checkCmd.contains("--json"))
    }
    
    // MARK: - Output Tests
    
    @Test("Handle command output parsing", tags: ["model", "output"])
    func testOutputParsing() throws {
        // Given
        let restic = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        // Test JSON output parsing
        let jsonOutput = """
        {
            "message_type": "status",
            "percent_done": 0.5,
            "total_files": 100,
            "files_done": 50,
            "total_bytes": 1024,
            "bytes_done": 512
        }
        """
        
        let status = restic.parseOutput(jsonOutput)
        #expect(status != nil)
        #expect(status?.progress == 0.5)
        #expect(status?.filesProcessed == 50)
        #expect(status?.totalFiles == 100)
        #expect(status?.bytesProcessed == 512)
        #expect(status?.totalBytes == 1024)
    }
    
    // MARK: - Error Tests
    
    @Test("Handle restic errors", tags: ["model", "error"])
    func testErrorHandling() throws {
        // Given
        let restic = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        // Test error parsing
        let errorOutput = """
        {
            "message_type": "error",
            "error": "repository not found",
            "code": 1
        }
        """
        
        let error = restic.parseError(errorOutput)
        #expect(error == .repositoryNotFound)
        
        // Test timeout error
        let timeoutOutput = """
        {
            "message_type": "error",
            "error": "timeout after 30s",
            "code": 2
        }
        """
        
        let timeoutError = restic.parseError(timeoutOutput)
        #expect(timeoutError == .timeout)
    }
    
    // MARK: - Configuration Tests
    
    @Test("Handle restic configuration", tags: ["model", "config"])
    func testConfiguration() throws {
        // Given
        var restic = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        // Test compression level
        let compressionLevels = [-1, 0, 6, 9, 10]
        for level in compressionLevels {
            let isValid = level >= 0 && level <= 9
            if isValid {
                restic.compressionLevel = level
                #expect(restic.compressionLevel == level)
            } else {
                let originalLevel = restic.compressionLevel
                restic.compressionLevel = level
                #expect(restic.compressionLevel == originalLevel)
            }
        }
        
        // Test parallel operations
        let parallelOps = [-1, 0, 4, 8, 16]
        for ops in parallelOps {
            let isValid = ops > 0 && ops <= 8
            if isValid {
                restic.parallelOperations = ops
                #expect(restic.parallelOperations == ops)
            } else {
                let originalOps = restic.parallelOperations
                restic.parallelOperations = ops
                #expect(restic.parallelOperations == originalOps)
            }
        }
    }
    
    // MARK: - Version Tests
    
    @Test("Handle restic version checks", tags: ["model", "version"])
    func testVersionChecks() throws {
        // Given
        let restic = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        let testCases = [
            ("0.15.1", true),
            ("0.14.0", true),
            ("0.13.0", false),
            ("invalid", false)
        ]
        
        for (version, isValid) in testCases {
            #expect(restic.isCompatibleVersion(version) == isValid)
        }
    }
    
    // MARK: - Repository Tests
    
    @Test("Handle repository operations", tags: ["model", "repository"])
    func testRepositoryOperations() throws {
        // Given
        let restic = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        // Test repository initialization
        let initCmd = restic.buildCommand(.init)
        #expect(initCmd.contains("init"))
        #expect(initCmd.contains("--json"))
        
        // Test repository check
        let checkCmd = restic.buildCommand(.check)
        #expect(checkCmd.contains("check"))
        #expect(checkCmd.contains("--json"))
        
        // Test repository statistics
        let statsCmd = restic.buildCommand(.stats)
        #expect(statsCmd.contains("stats"))
        #expect(statsCmd.contains("--json"))
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare restic instances for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let restic1 = BackupRestic(
            id: UUID(),
            repositoryId: UUID(),
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        let restic2 = BackupRestic(
            id: restic1.id,
            repositoryId: restic1.repositoryId,
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        let restic3 = BackupRestic(
            id: UUID(),
            repositoryId: restic1.repositoryId,
            executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
        )
        
        #expect(restic1 == restic2)
        #expect(restic1 != restic3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup restic", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic restic
            BackupRestic(
                id: UUID(),
                repositoryId: UUID(),
                executablePath: URL(fileURLWithPath: "/usr/local/bin/restic")
            ),
            // Full restic configuration
            BackupRestic(
                id: UUID(),
                repositoryId: UUID(),
                executablePath: URL(fileURLWithPath: "/usr/local/bin/restic"),
                version: "0.15.1",
                jsonOutput: true,
                compressionLevel: 6,
                parallelOperations: 4
            )
        ]
        
        for restic in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(restic)
            let decoded = try decoder.decode(BackupRestic.self, from: data)
            
            // Then
            #expect(decoded.id == restic.id)
            #expect(decoded.repositoryId == restic.repositoryId)
            #expect(decoded.executablePath == restic.executablePath)
            #expect(decoded.version == restic.version)
            #expect(decoded.jsonOutput == restic.jsonOutput)
            #expect(decoded.compressionLevel == restic.compressionLevel)
            #expect(decoded.parallelOperations == restic.parallelOperations)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup restic properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid restic
            (UUID(), UUID(), "/usr/local/bin/restic", "0.15.1", 6, 4, true),
            // Invalid path
            (UUID(), UUID(), "", "0.15.1", 6, 4, false),
            // Invalid version
            (UUID(), UUID(), "/usr/local/bin/restic", "0.13.0", 6, 4, false),
            // Invalid compression
            (UUID(), UUID(), "/usr/local/bin/restic", "0.15.1", 10, 4, false),
            // Invalid parallel ops
            (UUID(), UUID(), "/usr/local/bin/restic", "0.15.1", 6, 16, false)
        ]
        
        for (id, repoId, path, version, compression, parallel, isValid) in testCases {
            let restic = BackupRestic(
                id: id,
                repositoryId: repoId,
                executablePath: URL(fileURLWithPath: path),
                version: version,
                compressionLevel: compression,
                parallelOperations: parallel
            )
            
            if isValid {
                #expect(restic.isValid)
            } else {
                #expect(!restic.isValid)
            }
        }
    }
}
