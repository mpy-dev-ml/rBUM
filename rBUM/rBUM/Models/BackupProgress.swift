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
    /// Bytes processed so far
    let processedBytes: Int64
    /// Current file being processed
    let currentFile: String?
    /// Estimated seconds remaining
    let estimatedSecondsRemaining: TimeInterval?
    /// Start time of the backup
    let startTime: Date
    
    /// Percentage of files processed (0-100)
    var fileProgress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
    
    /// Percentage of bytes processed (0-100)
    var byteProgress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(processedBytes) / Double(totalBytes) * 100
    }
    
    /// Overall progress percentage (0-100), based on byte progress
    var overallProgress: Double {
        byteProgress
    }
    
    /// Elapsed time since backup started
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    /// Formats a time interval into a human-readable string
    /// - Parameter timeInterval: The time interval to format
    /// - Returns: A formatted string like "2h 30m" or "5m 30s"
    static func formatTimeInterval(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    /// Human-readable elapsed time
    var formattedElapsedTime: String {
        Self.formatTimeInterval(elapsedTime)
    }
    
    /// Human-readable estimated time remaining
    var formattedEstimatedTimeRemaining: String? {
        guard let remaining = estimatedSecondsRemaining else { return nil }
        return Self.formatTimeInterval(remaining)
    }
    
    /// Creates a string representation of the current progress
    /// - Returns: A string like "50% (5/10 files, 1.2GB/2.4GB)"
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
