//
//  BackupProgressTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupProgressTests {
    // MARK: - Progress Calculation Tests
    
    @Test("Progress calculation with various file and byte counts",
          .tags(.core, .unit, .backup),
          arguments: [
              (files: 100, processed: 50, bytes: 1000, processedBytes: 250, expected: 50.0),
              (files: 1000, processed: 250, bytes: 10000, processedBytes: 2500, expected: 25.0),
              (files: 50, processed: 50, bytes: 500, processedBytes: 500, expected: 100.0),
              (files: 0, processed: 0, bytes: 0, processedBytes: 0, expected: 0.0)
          ])
    func testProgressCalculation(files: Int, processed: Int, bytes: Int64, 
                               processedBytes: Int64, expected: Double) throws {
        let progress = BackupProgress(
            totalFiles: files,
            processedFiles: processed,
            totalBytes: bytes,
            processedBytes: processedBytes,
            currentFile: "test.txt",
            estimatedSecondsRemaining: 60,
            startTime: Date()
        )
        
        #expect(progress.fileProgress == (files == 0 ? 0 : Double(processed) / Double(files) * 100))
        #expect(progress.byteProgress == (bytes == 0 ? 0 : Double(processedBytes) / Double(bytes) * 100))
        #expect(progress.overallProgress == expected)
    }
    
    // MARK: - Time Formatting Tests
    
    @Test("Time remaining formatting for different durations",
          .tags(.core, .unit, .formatting),
          arguments: [
              (seconds: 30, expected: "30 seconds"),
              (seconds: 90, expected: "1 minute, 30 seconds"),
              (seconds: 3600, expected: "1 hour"),
              (seconds: 7200, expected: "2 hours"),
              (seconds: 3661, expected: "1 hour, 1 minute"),
              (seconds: nil, expected: "Calculating...")
          ])
    func testTimeFormatting(seconds: Int?, expected: String) throws {
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1000,
            processedBytes: 500,
            currentFile: "test.txt",
            estimatedSecondsRemaining: seconds,
            startTime: Date()
        )
        
        #expect(progress.formattedTimeRemaining == expected)
    }
    
    // MARK: - Restic Status Conversion Tests
    
    @Test("Convert Restic status to BackupProgress",
          .tags(.core, .unit, .integration))
    func testResticStatusConversion() throws {
        let startTime = Date()
        let status = ResticBackupStatus(
            messageType: "status",
            totalFiles: 100,
            filesProcessed: 75,
            totalBytes: 1000,
            bytesProcessed: 750,
            currentFile: "document.pdf",
            timeRemaining: 120
        )
        
        let progress = BackupProgress(from: status, startTime: startTime)
        
        #expect(progress.totalFiles == status.totalFiles)
        #expect(progress.processedFiles == status.filesProcessed)
        #expect(progress.totalBytes == status.totalBytes)
        #expect(progress.processedBytes == status.bytesProcessed)
        #expect(progress.currentFile == status.currentFile)
        #expect(progress.estimatedSecondsRemaining == status.timeRemaining)
        #expect(progress.startTime == startTime)
    }
    
    @Test("Handle invalid Restic status gracefully",
          .tags(.core, .unit, .error_handling))
    func testInvalidResticStatus() throws {
        let startTime = Date()
        let status = ResticBackupStatus(
            messageType: "invalid",
            totalFiles: -1,
            filesProcessed: -1,
            totalBytes: -1,
            bytesProcessed: -1,
            currentFile: nil,
            timeRemaining: nil
        )
        
        let progress = BackupProgress(from: status, startTime: startTime)
        
        #expect(progress.totalFiles == 0)
        #expect(progress.processedFiles == 0)
        #expect(progress.totalBytes == 0)
        #expect(progress.processedBytes == 0)
        #expect(progress.currentFile == nil)
        #expect(progress.estimatedSecondsRemaining == nil)
    }
}
