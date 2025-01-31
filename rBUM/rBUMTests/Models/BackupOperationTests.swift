//
//  BackupOperationTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupOperationTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup operation with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let type = BackupOperationType.backup
        let sourcePath = URL(fileURLWithPath: "/test/source")
        
        // When
        let operation = BackupOperation(
            id: id,
            repositoryId: repositoryId,
            type: type,
            sourcePath: sourcePath
        )
        
        // Then
        #expect(operation.id == id)
        #expect(operation.repositoryId == repositoryId)
        #expect(operation.type == type)
        #expect(operation.sourcePath == sourcePath)
        #expect(operation.status == .pending)
        #expect(operation.progress == 0)
        #expect(operation.error == nil)
        #expect(operation.startTime == nil)
        #expect(operation.endTime == nil)
    }
    
    @Test("Initialize backup operation with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let type = BackupOperationType.backup
        let sourcePath = URL(fileURLWithPath: "/test/source")
        let status = BackupOperationStatus.running
        let progress: Double = 0.5
        let startTime = Date(timeIntervalSinceNow: -3600)
        let endTime: Date? = nil
        let error: BackupError? = nil
        
        // When
        let operation = BackupOperation(
            id: id,
            repositoryId: repositoryId,
            type: type,
            sourcePath: sourcePath,
            status: status,
            progress: progress,
            startTime: startTime,
            endTime: endTime,
            error: error
        )
        
        // Then
        #expect(operation.id == id)
        #expect(operation.repositoryId == repositoryId)
        #expect(operation.type == type)
        #expect(operation.sourcePath == sourcePath)
        #expect(operation.status == status)
        #expect(operation.progress == progress)
        #expect(operation.startTime == startTime)
        #expect(operation.endTime == endTime)
        #expect(operation.error == error)
    }
    
    // MARK: - Status Tests
    
    @Test("Handle operation status transitions", tags: ["model", "status"])
    func testStatusTransitions() throws {
        let testCases: [(BackupOperationStatus, BackupOperationStatus, Bool)] = [
            // Valid transitions
            (.pending, .running, true),
            (.running, .completed, true),
            (.running, .failed, true),
            (.running, .cancelled, true),
            // Invalid transitions
            (.completed, .running, false),
            (.failed, .running, false),
            (.cancelled, .running, false),
            (.completed, .failed, false)
        ]
        
        for (fromStatus, toStatus, isValid) in testCases {
            var operation = BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test"),
                status: fromStatus
            )
            
            if isValid {
                operation.status = toStatus
                #expect(operation.status == toStatus)
            } else {
                operation.status = toStatus
                #expect(operation.status == fromStatus)
            }
        }
    }
    
    // MARK: - Progress Tests
    
    @Test("Handle operation progress updates", tags: ["model", "progress"])
    func testProgressUpdates() throws {
        let testCases: [(Double, Bool)] = [
            // Valid progress values
            (0.0, true),
            (0.5, true),
            (1.0, true),
            // Invalid progress values
            (-0.1, false),
            (1.1, false)
        ]
        
        for (progress, isValid) in testCases {
            var operation = BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test")
            )
            
            if isValid {
                operation.progress = progress
                #expect(operation.progress == progress)
                #expect(operation.formattedProgress == "\(Int(progress * 100))%")
            } else {
                let originalProgress = operation.progress
                operation.progress = progress
                #expect(operation.progress == originalProgress)
            }
        }
    }
    
    // MARK: - Error Tests
    
    @Test("Handle operation errors", tags: ["model", "error"])
    func testErrorHandling() throws {
        let testCases: [(BackupError?, BackupOperationStatus)] = [
            // No error
            (nil, .completed),
            // With errors
            (.repositoryNotFound, .failed),
            (.networkError, .failed),
            (.resticError("test error"), .failed)
        ]
        
        for (error, expectedStatus) in testCases {
            var operation = BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test"),
                status: .running
            )
            
            operation.error = error
            #expect(operation.error == error)
            #expect(operation.status == expectedStatus)
        }
    }
    
    // MARK: - Time Tests
    
    @Test("Handle operation time tracking", tags: ["model", "time"])
    func testTimeTracking() throws {
        // Given
        var operation = BackupOperation(
            id: UUID(),
            repositoryId: UUID(),
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test")
        )
        
        // When starting
        operation.status = .running
        #expect(operation.startTime != nil)
        #expect(operation.endTime == nil)
        
        // When completing
        operation.status = .completed
        #expect(operation.startTime != nil)
        #expect(operation.endTime != nil)
        #expect(operation.endTime! > operation.startTime!)
        
        // Duration should be calculated
        let duration = operation.endTime!.timeIntervalSince(operation.startTime!)
        #expect(duration >= 0)
        
        // Test duration formatting
        let formattedDuration = operation.formattedDuration
        #expect(!formattedDuration.isEmpty)
    }
    
    // MARK: - Cancellation Tests
    
    @Test("Handle operation cancellation", tags: ["model", "cancellation"])
    func testCancellation() throws {
        // Given
        var operation = BackupOperation(
            id: UUID(),
            repositoryId: UUID(),
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test"),
            status: .running,
            progress: 0.5
        )
        
        // When
        operation.cancel()
        
        // Then
        #expect(operation.status == .cancelled)
        #expect(operation.endTime != nil)
        #expect(operation.error == nil)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare operations for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let operation1 = BackupOperation(
            id: UUID(),
            repositoryId: UUID(),
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test"),
            status: .running,
            progress: 0.5
        )
        
        let operation2 = BackupOperation(
            id: operation1.id,
            repositoryId: operation1.repositoryId,
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test"),
            status: .running,
            progress: 0.5
        )
        
        let operation3 = BackupOperation(
            id: UUID(),
            repositoryId: operation1.repositoryId,
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test"),
            status: .running,
            progress: 0.5
        )
        
        #expect(operation1 == operation2)
        #expect(operation1 != operation3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup operation", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic operation
            BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test")
            ),
            // Running operation
            BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .restore,
                sourcePath: URL(fileURLWithPath: "/test"),
                status: .running,
                progress: 0.5,
                startTime: Date(timeIntervalSinceNow: -1800)
            ),
            // Failed operation
            BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .check,
                sourcePath: URL(fileURLWithPath: "/test"),
                status: .failed,
                progress: 0.7,
                startTime: Date(timeIntervalSinceNow: -3600),
                endTime: Date(timeIntervalSinceNow: -1800),
                error: .networkError
            )
        ]
        
        for operation in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(operation)
            let decoded = try decoder.decode(BackupOperation.self, from: data)
            
            // Then
            #expect(decoded.id == operation.id)
            #expect(decoded.repositoryId == operation.repositoryId)
            #expect(decoded.type == operation.type)
            #expect(decoded.sourcePath == operation.sourcePath)
            #expect(decoded.status == operation.status)
            #expect(decoded.progress == operation.progress)
            #expect(decoded.startTime == operation.startTime)
            #expect(decoded.endTime == operation.endTime)
            #expect(decoded.error == operation.error)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup operation properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid operation
            (UUID(), UUID(), .backup, "/test", .pending, 0.0, nil, true),
            // Invalid source path
            (UUID(), UUID(), .backup, "", .pending, 0.0, nil, false),
            // Invalid progress for completed status
            (UUID(), UUID(), .backup, "/test", .completed, 0.5, nil, false),
            // Missing error for failed status
            (UUID(), UUID(), .backup, "/test", .failed, 0.5, nil, false),
            // Valid failed operation
            (UUID(), UUID(), .backup, "/test", .failed, 0.5, .networkError, true)
        ]
        
        for (id, repoId, type, path, status, progress, error, isValid) in testCases {
            let operation = BackupOperation(
                id: id,
                repositoryId: repoId,
                type: type,
                sourcePath: URL(fileURLWithPath: path),
                status: status,
                progress: progress,
                error: error
            )
            
            if isValid {
                #expect(operation.isValid)
            } else {
                #expect(!operation.isValid)
            }
        }
    }
}
