//
//  BackupProgress.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Represents the current status of a backup operation
enum BackupStatus {
    /// Backup is being prepared (scanning files, calculating sizes)
    case preparing
    /// Backup is actively processing files
    case backing(BackupProgress)
    /// Backup is finalising (creating snapshot, cleaning up)
    case finalising
    /// Backup completed successfully
    case completed
    /// Backup failed with an error
    case failed(Error)
    /// Backup was cancelled by the user
    case cancelled
    
    var isActive: Bool {
        switch self {
        case .preparing, .backing, .finalising:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }
}

// MARK: - BackupStatus Equatable
extension BackupStatus: Equatable {
    static func == (lhs: BackupStatus, rhs: BackupStatus) -> Bool {
        switch (lhs, rhs) {
        case (.preparing, .preparing):
            return true
        case (.backing(let lhsProgress), .backing(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.finalising, .finalising):
            return true
        case (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            // Compare error descriptions since Error doesn't conform to Equatable
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

/// Represents the progress of a backup operation
struct BackupProgress: Equatable {
    /// Total number of files to backup
    let totalFiles: Int
    /// Number of files processed so far
    let processedFiles: Int
    /// Total bytes to backup
    let totalBytes: Int64
    /// Number of bytes processed so far
    let processedBytes: Int64
    /// Currently processing file
    let currentFile: String?
    /// Estimated seconds remaining
    let estimatedSecondsRemaining: TimeInterval?
    /// Time when backup started
    let startTime: Date
    
    /// Progress as percentage of files processed (0-100)
    var fileProgress: Double {
        totalFiles > 0 ? (Double(processedFiles) / Double(totalFiles)) * 100 : 0
    }
    
    /// Progress as percentage of bytes processed (0-100)
    var byteProgress: Double {
        totalBytes > 0 ? (Double(processedBytes) / Double(totalBytes)) * 100 : 0
    }
    
    /// Overall progress as percentage of files processed (0-100)
    var overallProgress: Double {
        fileProgress
    }
    
    /// Formatted string for time remaining
    var formattedTimeRemaining: String {
        guard let seconds = estimatedSecondsRemaining else {
            return "Calculating..."
        }
        return formatDuration(seconds: Int(seconds))
    }
    
    /// Formatted string for elapsed time
    var formattedElapsedTime: String {
        let elapsed = -startTime.timeIntervalSinceNow
        if elapsed < 1 {
            return "Just started"
        }
        return formatDuration(seconds: Int(elapsed))
    }
    
    /// Format progress as a string with file and byte counts
    func formattedProgress() -> String {
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        
        let processedBytesStr = byteFormatter.string(fromByteCount: processedBytes)
        let totalBytesStr = byteFormatter.string(fromByteCount: totalBytes)
        
        return String(
            format: "%.1f%% (%d/%d files, %@/%@)",
            overallProgress,
            processedFiles,
            totalFiles,
            processedBytesStr,
            totalBytesStr
        )
    }
    
    /// Format duration in seconds to human-readable string
    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            return "Less than a minute"
        }
        return parts.joined(separator: ", ")
    }
    
    static func == (lhs: BackupProgress, rhs: BackupProgress) -> Bool {
        lhs.totalFiles == rhs.totalFiles &&
        lhs.processedFiles == rhs.processedFiles &&
        lhs.totalBytes == rhs.totalBytes &&
        lhs.processedBytes == rhs.processedBytes &&
        lhs.currentFile == rhs.currentFile &&
        lhs.estimatedSecondsRemaining == rhs.estimatedSecondsRemaining &&
        lhs.startTime == rhs.startTime
    }
}

/// Represents a line of JSON output from the restic backup command
struct ResticBackupStatus: Codable {
    /// Message type from restic
    let messageType: String
    /// Total number of files
    let totalFiles: Int?
    /// Files processed
    let filesProcessed: Int?
    /// Total bytes
    let totalBytes: Int64?
    /// Bytes processed
    let bytesProcessed: Int64?
    /// Current file being processed
    let currentFile: String?
    /// Seconds elapsed
    let secondsElapsed: Double?
    /// Seconds remaining (estimated)
    let secondsRemaining: Double?
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case totalFiles = "total_files"
        case filesProcessed = "files_done"
        case totalBytes = "total_bytes"
        case bytesProcessed = "bytes_done"
        case currentFile = "current_file"
        case secondsElapsed = "seconds_elapsed"
        case secondsRemaining = "seconds_remaining"
    }
    
    /// Convert restic status to backup progress
    func toBackupProgress(startTime: Date) -> BackupProgress? {
        guard messageType == "status",
              let totalFiles = totalFiles,
              let filesProcessed = filesProcessed,
              let totalBytes = totalBytes,
              let bytesProcessed = bytesProcessed else {
            return nil
        }
        
        return BackupProgress(
            totalFiles: totalFiles,
            processedFiles: filesProcessed,
            totalBytes: totalBytes,
            processedBytes: bytesProcessed,
            currentFile: currentFile,
            estimatedSecondsRemaining: secondsRemaining,
            startTime: startTime
        )
    }
}
