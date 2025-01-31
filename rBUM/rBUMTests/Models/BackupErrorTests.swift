//
//  BackupErrorTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupErrorTests {
    // MARK: - Basic Tests
    
    @Test("Test all backup error types", tags: ["basic", "model", "error"])
    func testBackupErrorTypes() throws {
        let testCases: [(BackupError, String)] = [
            (.repositoryNotFound, "Repository not found"),
            (.sourcePathNotFound, "Source path not found"),
            (.insufficientPermissions, "Insufficient permissions"),
            (.networkError, "Network error occurred"),
            (.outOfSpace, "Insufficient disk space"),
            (.repositoryLocked, "Repository is locked"),
            (.invalidConfiguration, "Invalid backup configuration"),
            (.resticError("test error"), "Restic error: test error")
        ]
        
        for (error, expectedDescription) in testCases {
            #expect(error.description == expectedDescription)
        }
    }
    
    // MARK: - Localization Tests
    
    @Test("Test error localization", tags: ["model", "error", "localization"])
    func testErrorLocalization() throws {
        let testCases: [(BackupError, String)] = [
            (.repositoryNotFound, "The backup repository could not be found. Please verify the repository path and credentials."),
            (.sourcePathNotFound, "The source path for backup could not be found. Please verify the path exists and is accessible."),
            (.insufficientPermissions, "Insufficient permissions to access the backup location. Please check file system permissions."),
            (.networkError, "A network error occurred during the backup operation. Please check your network connection."),
            (.outOfSpace, "There is not enough disk space to complete the backup operation."),
            (.repositoryLocked, "The repository is currently locked by another operation. Please try again later."),
            (.invalidConfiguration, "The backup configuration is invalid. Please check your settings."),
            (.resticError("test error"), "Restic encountered an error: test error")
        ]
        
        for (error, expectedLocalizedDescription) in testCases {
            #expect(error.localizedDescription == expectedLocalizedDescription)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup errors for equality", tags: ["model", "error", "comparison"])
    func testEquatable() throws {
        // Test basic error types
        #expect(BackupError.repositoryNotFound == BackupError.repositoryNotFound)
        #expect(BackupError.sourcePathNotFound != BackupError.repositoryNotFound)
        
        // Test restic errors
        #expect(BackupError.resticError("test") == BackupError.resticError("test"))
        #expect(BackupError.resticError("test1") != BackupError.resticError("test2"))
        #expect(BackupError.resticError("test") != BackupError.repositoryNotFound)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup errors", tags: ["model", "error", "serialization"])
    func testCodable() throws {
        let testCases: [BackupError] = [
            .repositoryNotFound,
            .sourcePathNotFound,
            .insufficientPermissions,
            .networkError,
            .outOfSpace,
            .repositoryLocked,
            .invalidConfiguration,
            .resticError("test error")
        ]
        
        for error in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(error)
            let decoded = try decoder.decode(BackupError.self, from: data)
            
            // Then
            #expect(decoded == error)
            #expect(decoded.description == error.description)
            #expect(decoded.localizedDescription == error.localizedDescription)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle error conversion to NSError", tags: ["model", "error", "conversion"])
    func testNSErrorConversion() throws {
        let testCases: [(BackupError, Int)] = [
            (.repositoryNotFound, 1001),
            (.sourcePathNotFound, 1002),
            (.insufficientPermissions, 1003),
            (.networkError, 1004),
            (.outOfSpace, 1005),
            (.repositoryLocked, 1006),
            (.invalidConfiguration, 1007),
            (.resticError("test"), 1008)
        ]
        
        for (error, expectedCode) in testCases {
            let nsError = error as NSError
            #expect(nsError.domain == "dev.mpy.rBUM.BackupError")
            #expect(nsError.code == expectedCode)
            #expect(nsError.localizedDescription == error.localizedDescription)
        }
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("Test error recovery options", tags: ["model", "error", "recovery"])
    func testErrorRecoveryOptions() throws {
        let testCases: [(BackupError, [String])] = [
            (.repositoryNotFound, [
                "Check repository path",
                "Verify repository credentials",
                "Initialize new repository"
            ]),
            (.sourcePathNotFound, [
                "Check source path",
                "Verify file permissions",
                "Update backup configuration"
            ]),
            (.insufficientPermissions, [
                "Check file permissions",
                "Run with elevated privileges",
                "Update access rights"
            ]),
            (.networkError, [
                "Check network connection",
                "Verify VPN status",
                "Retry operation"
            ]),
            (.outOfSpace, [
                "Free up disk space",
                "Choose different location",
                "Reduce backup scope"
            ]),
            (.repositoryLocked, [
                "Wait and retry",
                "Force unlock repository",
                "Check running operations"
            ]),
            (.invalidConfiguration, [
                "Review configuration",
                "Reset to defaults",
                "Check documentation"
            ]),
            (.resticError("test"), [
                "Check restic logs",
                "Verify restic version",
                "Contact support"
            ])
        ]
        
        for (error, expectedOptions) in testCases {
            #expect(error.recoveryOptions == expectedOptions)
        }
    }
    
    // MARK: - Error Context Tests
    
    @Test("Test error context information", tags: ["model", "error", "context"])
    func testErrorContext() throws {
        let testCases: [(BackupError, [String: String])] = [
            (.repositoryNotFound, [
                "errorType": "repository",
                "severity": "critical",
                "recoverable": "true"
            ]),
            (.sourcePathNotFound, [
                "errorType": "filesystem",
                "severity": "critical",
                "recoverable": "true"
            ]),
            (.insufficientPermissions, [
                "errorType": "permissions",
                "severity": "high",
                "recoverable": "true"
            ]),
            (.networkError, [
                "errorType": "network",
                "severity": "medium",
                "recoverable": "true"
            ]),
            (.outOfSpace, [
                "errorType": "storage",
                "severity": "critical",
                "recoverable": "true"
            ]),
            (.repositoryLocked, [
                "errorType": "concurrency",
                "severity": "medium",
                "recoverable": "true"
            ]),
            (.invalidConfiguration, [
                "errorType": "configuration",
                "severity": "high",
                "recoverable": "true"
            ]),
            (.resticError("test"), [
                "errorType": "restic",
                "severity": "unknown",
                "recoverable": "unknown",
                "resticMessage": "test"
            ])
        ]
        
        for (error, expectedContext) in testCases {
            let context = error.errorContext
            for (key, value) in expectedContext {
                #expect(context[key] == value, "Context key '\(key)' has incorrect value")
            }
        }
    }
}
