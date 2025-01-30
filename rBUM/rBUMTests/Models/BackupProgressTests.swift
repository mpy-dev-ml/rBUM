//
//  BackupProgressTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

struct BackupProgressTests {
    @Test("BackupProgress calculates progress correctly")
    func testBackupProgressCalculation() throws {
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1000,
            processedBytes: 250,
            currentFile: "test.txt",
            estimatedSecondsRemaining: 60,
            startTime: Date()
        )
        
        #expect(progress.fileProgress == 50.0)
        #expect(progress.byteProgress == 25.0)
        #expect(progress.overallProgress == 37.5)
    }
    
    @Test("BackupProgress handles zero totals")
    func testBackupProgressZeroTotals() throws {
        let progress = BackupProgress(
            totalFiles: 0,
            processedFiles: 0,
            totalBytes: 0,
            processedBytes: 0,
            currentFile: nil,
            estimatedSecondsRemaining: nil,
            startTime: Date()
        )
        
        #expect(progress.fileProgress == 0)
        #expect(progress.byteProgress == 0)
        #expect(progress.overallProgress == 0)
    }
    
    @Test("BackupProgress formats time remaining correctly")
    func testTimeFormatting() throws {
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1000,
            processedBytes: 500,
            currentFile: "test.txt",
            estimatedSecondsRemaining: 3665, // 1h 1m 5s
            startTime: Date()
        )
        
        #expect(progress.formattedTimeRemaining == "1h 1m")
    }
    
    @Test("ResticBackupStatus converts to BackupProgress correctly")
    func testResticStatusConversion() throws {
        let startTime = Date()
        let status = ResticBackupStatus(
            messageType: "status",
            totalFiles: 100,
            filesProcessed: 50,
            totalBytes: 1000,
            bytesProcessed: 500,
            currentFile: "test.txt",
            secondsElapsed: 30,
            secondsRemaining: 60
        )
        
        let progress = status.toBackupProgress(startTime: startTime)
        #expect(progress != nil)
        #expect(progress?.totalFiles == 100)
        #expect(progress?.processedFiles == 50)
        #expect(progress?.totalBytes == 1000)
        #expect(progress?.processedBytes == 500)
        #expect(progress?.currentFile == "test.txt")
        #expect(progress?.estimatedSecondsRemaining == 60)
        #expect(progress?.startTime == startTime)
    }
    
    @Test("ResticBackupStatus returns nil for non-status messages")
    func testResticStatusNonStatusMessage() throws {
        let status = ResticBackupStatus(
            messageType: "summary",
            totalFiles: 100,
            filesProcessed: 50,
            totalBytes: 1000,
            bytesProcessed: 500,
            currentFile: "test.txt",
            secondsElapsed: 30,
            secondsRemaining: 60
        )
        
        let progress = status.toBackupProgress(startTime: Date())
        #expect(progress == nil)
    }
    
    @Test("BackupStatus isActive property works correctly")
    func testBackupStatusIsActive() throws {
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1000,
            processedBytes: 500,
            currentFile: "test.txt",
            estimatedSecondsRemaining: 60,
            startTime: Date()
        )
        
        #expect(BackupStatus.preparing.isActive == true)
        #expect(BackupStatus.backing(progress).isActive == true)
        #expect(BackupStatus.finalising.isActive == true)
        #expect(BackupStatus.completed.isActive == false)
        #expect(BackupStatus.cancelled.isActive == false)
        #expect(BackupStatus.failed(ResticError.backupFailed("test")).isActive == false)
    }
}
