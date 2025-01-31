//
//  BackupJobTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupJobTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup job with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let type = BackupJobType.backup
        
        // When
        let job = BackupJob(
            id: id,
            repositoryId: repositoryId,
            type: type
        )
        
        // Then
        #expect(job.id == id)
        #expect(job.repositoryId == repositoryId)
        #expect(job.type == type)
        #expect(job.status == .pending)
        #expect(job.createdAt.timeIntervalSinceNow <= 0)
        #expect(job.startedAt == nil)
        #expect(job.completedAt == nil)
        #expect(job.progress == 0)
        #expect(job.error == nil)
    }
    
    @Test("Initialize backup job with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let type = BackupJobType.backup
        let status = BackupJobStatus.running
        let createdAt = Date(timeIntervalSinceNow: -3600)
        let startedAt = Date(timeIntervalSinceNow: -1800)
        let completedAt: Date? = nil
        let progress: Double = 0.5
        let error: BackupError? = nil
        
        // When
        let job = BackupJob(
            id: id,
            repositoryId: repositoryId,
            type: type,
            status: status,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: completedAt,
            progress: progress,
            error: error
        )
        
        // Then
        #expect(job.id == id)
        #expect(job.repositoryId == repositoryId)
        #expect(job.type == type)
        #expect(job.status == status)
        #expect(job.createdAt == createdAt)
        #expect(job.startedAt == startedAt)
        #expect(job.completedAt == completedAt)
        #expect(job.progress == progress)
        #expect(job.error == error)
    }
    
    // MARK: - Type Tests
    
    @Test("Handle job types", tags: ["model", "type"])
    func testJobTypes() throws {
        let testCases: [(BackupJobType, String)] = [
            (.backup, "Backup"),
            (.restore, "Restore"),
            (.check, "Check"),
            (.prune, "Prune"),
            (.init, "Initialise")
        ]
        
        for (type, description) in testCases {
            let job = BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: type
            )
            
            #expect(job.type == type)
            #expect(job.type.description == description)
        }
    }
    
    // MARK: - Status Tests
    
    @Test("Handle job status transitions", tags: ["model", "status"])
    func testStatusTransitions() throws {
        let testCases: [(BackupJobStatus, BackupJobStatus, Bool)] = [
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
            var job = BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                status: fromStatus
            )
            
            if isValid {
                job.status = toStatus
                #expect(job.status == toStatus)
            } else {
                job.status = toStatus
                #expect(job.status == fromStatus)
            }
        }
    }
    
    // MARK: - Progress Tests
    
    @Test("Handle job progress updates", tags: ["model", "progress"])
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
            var job = BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup
            )
            
            if isValid {
                job.progress = progress
                #expect(job.progress == progress)
                #expect(job.formattedProgress == "\(Int(progress * 100))%")
            } else {
                let originalProgress = job.progress
                job.progress = progress
                #expect(job.progress == originalProgress)
            }
        }
    }
    
    // MARK: - Duration Tests
    
    @Test("Calculate job duration", tags: ["model", "duration"])
    func testDurationCalculation() throws {
        let testCases: [(TimeInterval?, TimeInterval?, String)] = [
            // Not started
            (nil, nil, "Not started"),
            // Running
            (-1800, nil, "30 minutes"),
            // Completed
            (-3600, -1800, "30 minutes"),
            // Very short duration
            (-1, 0, "1 second"),
            // Long duration
            (-86400, -43200, "12 hours")
        ]
        
        for (startOffset, completedOffset, expected) in testCases {
            let job = BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                startedAt: startOffset.map { Date(timeIntervalSinceNow: $0) },
                completedAt: completedOffset.map { Date(timeIntervalSinceNow: $0) }
            )
            
            #expect(job.formattedDuration == expected)
        }
    }
    
    // MARK: - Error Tests
    
    @Test("Handle job errors", tags: ["model", "error"])
    func testErrors() throws {
        let testCases: [(BackupError?, BackupJobStatus)] = [
            // No error
            (nil, .completed),
            // With error
            (.repositoryNotFound, .failed),
            (.networkError, .failed),
            (.resticError("test error"), .failed)
        ]
        
        for (error, expectedStatus) in testCases {
            var job = BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                status: .running
            )
            
            job.error = error
            #expect(job.error == error)
            #expect(job.status == expectedStatus)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup jobs for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let job1 = BackupJob(
            id: UUID(),
            repositoryId: UUID(),
            type: .backup,
            status: .running,
            progress: 0.5
        )
        
        let job2 = BackupJob(
            id: job1.id,
            repositoryId: job1.repositoryId,
            type: .backup,
            status: .running,
            progress: 0.5
        )
        
        let job3 = BackupJob(
            id: UUID(),
            repositoryId: job1.repositoryId,
            type: .backup,
            status: .running,
            progress: 0.5
        )
        
        #expect(job1 == job2)
        #expect(job1 != job3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup job", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic job
            BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup
            ),
            // Running job
            BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .restore,
                status: .running,
                startedAt: Date(timeIntervalSinceNow: -1800),
                progress: 0.5
            ),
            // Failed job
            BackupJob(
                id: UUID(),
                repositoryId: UUID(),
                type: .check,
                status: .failed,
                startedAt: Date(timeIntervalSinceNow: -3600),
                completedAt: Date(timeIntervalSinceNow: -1800),
                error: .networkError
            )
        ]
        
        for job in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(job)
            let decoded = try decoder.decode(BackupJob.self, from: data)
            
            // Then
            #expect(decoded.id == job.id)
            #expect(decoded.repositoryId == job.repositoryId)
            #expect(decoded.type == job.type)
            #expect(decoded.status == job.status)
            #expect(decoded.createdAt == job.createdAt)
            #expect(decoded.startedAt == job.startedAt)
            #expect(decoded.completedAt == job.completedAt)
            #expect(decoded.progress == job.progress)
            #expect(decoded.error == job.error)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup job properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid job
            (UUID(), UUID(), .backup, .pending, 0.0, nil, true),
            // Valid completed job
            (UUID(), UUID(), .backup, .completed, 1.0, nil, true),
            // Valid failed job
            (UUID(), UUID(), .backup, .failed, 0.5, .networkError, true),
            // Invalid progress for completed
            (UUID(), UUID(), .backup, .completed, 0.5, nil, false),
            // Missing error for failed
            (UUID(), UUID(), .backup, .failed, 0.5, nil, false)
        ]
        
        for (id, repoId, type, status, progress, error, isValid) in testCases {
            let job = BackupJob(
                id: id,
                repositoryId: repoId,
                type: type,
                status: status,
                progress: progress,
                error: error
            )
            
            if isValid {
                #expect(job.isValid)
            } else {
                #expect(!job.isValid)
            }
        }
    }
}
