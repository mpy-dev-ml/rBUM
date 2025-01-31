//
//  BackupHistoryTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupHistoryTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup history with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let configId = UUID()
        let startTime = Date()
        let endTime = Date(timeIntervalSinceNow: 3600)
        let status = BackupStatus.completed
        
        // When
        let history = BackupHistory(
            id: id,
            configurationId: configId,
            startTime: startTime,
            endTime: endTime,
            status: status
        )
        
        // Then
        #expect(history.id == id)
        #expect(history.configurationId == configId)
        #expect(history.startTime == startTime)
        #expect(history.endTime == endTime)
        #expect(history.status == status)
        #expect(history.error == nil)
        #expect(history.statistics == nil)
    }
    
    @Test("Initialize backup history with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let configId = UUID()
        let startTime = Date()
        let endTime = Date(timeIntervalSinceNow: 3600)
        let status = BackupStatus.failed
        let error = BackupError.repositoryNotFound
        let stats = BackupStatistics(
            filesChanged: 10,
            filesNew: 5,
            filesUnmodified: 100,
            dataAdded: 1024 * 1024,
            totalDuration: 3600
        )
        
        // When
        let history = BackupHistory(
            id: id,
            configurationId: configId,
            startTime: startTime,
            endTime: endTime,
            status: status,
            error: error,
            statistics: stats
        )
        
        // Then
        #expect(history.id == id)
        #expect(history.configurationId == configId)
        #expect(history.startTime == startTime)
        #expect(history.endTime == endTime)
        #expect(history.status == status)
        #expect(history.error == error)
        #expect(history.statistics == stats)
    }
    
    // MARK: - Status Tests
    
    @Test("Handle all backup status types", tags: ["model", "status"])
    func testBackupStatus() throws {
        let testCases = [
            (BackupStatus.pending, "Pending backup"),
            (BackupStatus.inProgress, "Backup in progress"),
            (BackupStatus.completed, "Successful backup"),
            (BackupStatus.failed, "Failed backup"),
            (BackupStatus.cancelled, "Cancelled backup")
        ]
        
        for (status, description) in testCases {
            let history = BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: Date(),
                endTime: Date(),
                status: status
            )
            
            #expect(history.status == status)
            #expect(history.status.description == description)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle various backup errors", tags: ["model", "error"])
    func testBackupErrors() throws {
        let testCases = [
            BackupError.repositoryNotFound,
            BackupError.sourcePathNotFound,
            BackupError.insufficientPermissions,
            BackupError.networkError,
            BackupError.outOfSpace,
            BackupError.repositoryLocked,
            BackupError.invalidConfiguration,
            BackupError.resticError("test error")
        ]
        
        for error in testCases {
            let history = BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: Date(),
                endTime: Date(),
                status: .failed,
                error: error
            )
            
            #expect(history.error == error)
            #expect(history.status == .failed)
        }
    }
    
    // MARK: - Statistics Tests
    
    @Test("Handle backup statistics", tags: ["model", "statistics"])
    func testBackupStatistics() throws {
        let testCases = [
            // Empty backup
            BackupStatistics(
                filesChanged: 0,
                filesNew: 0,
                filesUnmodified: 0,
                dataAdded: 0,
                totalDuration: 0
            ),
            // Small backup
            BackupStatistics(
                filesChanged: 5,
                filesNew: 2,
                filesUnmodified: 10,
                dataAdded: 1024,
                totalDuration: 60
            ),
            // Large backup
            BackupStatistics(
                filesChanged: 1000,
                filesNew: 500,
                filesUnmodified: 10000,
                dataAdded: 1024 * 1024 * 1024,
                totalDuration: 3600
            )
        ]
        
        for stats in testCases {
            let history = BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: Date(),
                endTime: Date(),
                status: .completed,
                statistics: stats
            )
            
            #expect(history.statistics == stats)
            #expect(history.statistics?.totalFiles == stats.filesChanged + stats.filesNew + stats.filesUnmodified)
            #expect(history.statistics?.averageSpeed == Double(stats.dataAdded) / stats.totalDuration)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup histories for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        // Given
        let id = UUID()
        let configId = UUID()
        let startTime = Date()
        let endTime = Date()
        let stats = BackupStatistics(
            filesChanged: 10,
            filesNew: 5,
            filesUnmodified: 100,
            dataAdded: 1024,
            totalDuration: 60
        )
        
        let history1 = BackupHistory(
            id: id,
            configurationId: configId,
            startTime: startTime,
            endTime: endTime,
            status: .completed,
            statistics: stats
        )
        
        let history2 = BackupHistory(
            id: id,
            configurationId: configId,
            startTime: startTime,
            endTime: endTime,
            status: .completed,
            statistics: stats
        )
        
        let history3 = BackupHistory(
            id: UUID(),
            configurationId: configId,
            startTime: startTime,
            endTime: endTime,
            status: .completed,
            statistics: stats
        )
        
        // Then
        #expect(history1 == history2)
        #expect(history1 != history3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup history", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic history
            BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: Date(),
                endTime: Date(),
                status: .completed
            ),
            // History with error
            BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: Date(),
                endTime: Date(),
                status: .failed,
                error: .repositoryNotFound
            ),
            // History with statistics
            BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: Date(),
                endTime: Date(),
                status: .completed,
                statistics: BackupStatistics(
                    filesChanged: 10,
                    filesNew: 5,
                    filesUnmodified: 100,
                    dataAdded: 1024,
                    totalDuration: 60
                )
            )
        ]
        
        for history in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(history)
            let decoded = try decoder.decode(BackupHistory.self, from: data)
            
            // Then
            #expect(decoded.id == history.id)
            #expect(decoded.configurationId == history.configurationId)
            #expect(decoded.startTime == history.startTime)
            #expect(decoded.endTime == history.endTime)
            #expect(decoded.status == history.status)
            #expect(decoded.error == history.error)
            #expect(decoded.statistics == history.statistics)
        }
    }
    
    // MARK: - Duration Tests
    
    @Test("Calculate backup duration", tags: ["model", "duration"])
    func testBackupDuration() throws {
        let testCases = [
            // Zero duration
            (Date(), Date(), 0.0),
            // One hour duration
            (Date(), Date(timeIntervalSinceNow: 3600), 3600.0),
            // One day duration
            (Date(), Date(timeIntervalSinceNow: 86400), 86400.0)
        ]
        
        for (startTime, endTime, expectedDuration) in testCases {
            let history = BackupHistory(
                id: UUID(),
                configurationId: UUID(),
                startTime: startTime,
                endTime: endTime,
                status: .completed
            )
            
            #expect(abs(history.duration - expectedDuration) < 0.001)
        }
    }
}
