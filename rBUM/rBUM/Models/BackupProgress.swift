//
//  BackupProgress.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Represents the current status of a backup operation
public enum ResticBackupStatus: Codable {
    /// Backup is being prepared (scanning files, calculating sizes)
    case preparing
    /// Backup is actively processing files
    case backing(ResticBackupProgress)
    /// Backup is finalising (creating snapshot, cleaning up)
    case finalising
    /// Backup completed successfully
    case completed
    /// Backup failed with an error
    case failed(Error)
    /// Backup was cancelled by the user
    case cancelled
    
    public var isActive: Bool {
        switch self {
        case .preparing, .backing, .finalising:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case type
        case progress
        case error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "preparing":
            self = .preparing
        case "backing":
            let progress = try container.decode(ResticBackupProgress.self, forKey: .progress)
            self = .backing(progress)
        case "finalising":
            self = .finalising
        case "completed":
            self = .completed
        case "failed":
            let errorMessage = try container.decode(String.self, forKey: .error)
            self = .failed(NSError(domain: "ResticBackup", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
        case "cancelled":
            self = .cancelled
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid status type")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .preparing:
            try container.encode("preparing", forKey: .type)
        case .backing(let progress):
            try container.encode("backing", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case .finalising:
            try container.encode("finalising", forKey: .type)
        case .completed:
            try container.encode("completed", forKey: .type)
        case .failed(let error):
            try container.encode("failed", forKey: .type)
            try container.encode(error.localizedDescription, forKey: .error)
        case .cancelled:
            try container.encode("cancelled", forKey: .type)
        }
    }
}

// MARK: - ResticBackupStatus Equatable
extension ResticBackupStatus: Equatable {
    public static func == (lhs: ResticBackupStatus, rhs: ResticBackupStatus) -> Bool {
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
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}

/// Represents the progress of a backup operation
public struct ResticBackupProgress: Codable, Equatable {
    /// Total number of files to backup
    public let totalFiles: Int
    /// Number of files processed so far
    public let processedFiles: Int
    /// Total data size to backup in bytes
    public let totalBytes: Int64
    /// Number of bytes processed so far
    public let processedBytes: Int64
    /// Current file being processed
    public let currentFile: String?
    /// Time when the backup started
    public let startTime: Date
    /// Time when the progress was last updated
    public let updatedAt: Date
    
    /// Percentage of files processed (0-100)
    public var fileProgress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
    
    /// Percentage of bytes processed (0-100)
    public var byteProgress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(processedBytes) / Double(totalBytes) * 100
    }
    
    /// Average speed in bytes per second
    public var averageSpeed: Double {
        let duration = updatedAt.timeIntervalSince(startTime)
        guard duration > 0 else { return 0 }
        return Double(processedBytes) / duration
    }
    
    /// Estimated time remaining in seconds
    public var estimatedTimeRemaining: TimeInterval? {
        guard averageSpeed > 0 else { return nil }
        let remainingBytes = Double(totalBytes - processedBytes)
        return remainingBytes / averageSpeed
    }
    
    public init(
        totalFiles: Int,
        processedFiles: Int,
        totalBytes: Int64,
        processedBytes: Int64,
        currentFile: String?,
        startTime: Date,
        updatedAt: Date
    ) {
        self.totalFiles = totalFiles
        self.processedFiles = processedFiles
        self.totalBytes = totalBytes
        self.processedBytes = processedBytes
        self.currentFile = currentFile
        self.startTime = startTime
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case totalFiles
        case processedFiles
        case totalBytes
        case processedBytes
        case currentFile
        case startTime
        case updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        totalFiles = try container.decode(Int.self, forKey: .totalFiles)
        processedFiles = try container.decode(Int.self, forKey: .processedFiles)
        totalBytes = try container.decode(Int64.self, forKey: .totalBytes)
        processedBytes = try container.decode(Int64.self, forKey: .processedBytes)
        currentFile = try container.decodeIfPresent(String.self, forKey: .currentFile)
        startTime = try container.decode(Date.self, forKey: .startTime)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(totalFiles, forKey: .totalFiles)
        try container.encode(processedFiles, forKey: .processedFiles)
        try container.encode(totalBytes, forKey: .totalBytes)
        try container.encode(processedBytes, forKey: .processedBytes)
        try container.encodeIfPresent(currentFile, forKey: .currentFile)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - ResticBackupProgress Equatable
extension ResticBackupProgress {
    public static func == (lhs: ResticBackupProgress, rhs: ResticBackupProgress) -> Bool {
        lhs.totalFiles == rhs.totalFiles &&
        lhs.processedFiles == rhs.processedFiles &&
        lhs.totalBytes == rhs.totalBytes &&
        lhs.processedBytes == rhs.processedBytes &&
        lhs.currentFile == rhs.currentFile &&
        lhs.startTime == rhs.startTime &&
        lhs.updatedAt == rhs.updatedAt
    }
}

/// JSON response from restic backup command
public struct ResticBackupResponse: Codable {
    let messageType: String
    let filesNew: Int?
    let filesChanged: Int?
    let filesUnmodified: Int?
    let dirsNew: Int?
    let dirsChanged: Int?
    let dirsUnmodified: Int?
    let dataBlobs: Int?
    let treeBlobs: Int?
    let dataMiBs: Double?
    let treeMiBs: Double?
    let totalFilesProcessed: Int?
    let totalBytesProcessed: Int64?
    let currentFile: String?
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case filesNew = "files_new"
        case filesChanged = "files_changed"
        case filesUnmodified = "files_unmodified"
        case dirsNew = "dirs_new"
        case dirsChanged = "dirs_changed"
        case dirsUnmodified = "dirs_unmodified"
        case dataBlobs = "data_blobs"
        case treeBlobs = "tree_blobs"
        case dataMiBs = "data_added"
        case treeMiBs = "total_files_processed"
        case totalFilesProcessed = "total_bytes_processed"
        case totalBytesProcessed = "bytes_processed"
        case currentFile = "current_file"
    }
    
    func toBackupProgress(startTime: Date) -> ResticBackupProgress {
        let totalFiles = (filesNew ?? 0) + (filesChanged ?? 0) + (filesUnmodified ?? 0)
        let processedFiles = totalFilesProcessed ?? 0
        let totalBytes = Int64((dataMiBs ?? 0) * 1024 * 1024)
        let processedBytes = totalBytesProcessed ?? 0
        
        return ResticBackupProgress(
            totalFiles: totalFiles,
            processedFiles: processedFiles,
            totalBytes: totalBytes,
            processedBytes: processedBytes,
            currentFile: currentFile,
            startTime: startTime,
            updatedAt: Date()
        )
    }
}
