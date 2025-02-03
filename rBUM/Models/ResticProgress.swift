import Foundation
import Core

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
    case failed(ResticBackupError)
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
}

/// Progress information for a Restic backup operation
public struct ResticBackupProgress: Codable, Equatable {
    public let totalFiles: Int
    public let processedFiles: Int
    public let totalBytes: Int64
    public let processedBytes: Int64
    public let currentFile: String
    public let startTime: Date
    public let updatedAt: Date
    
    public var percentComplete: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(processedBytes) / Double(totalBytes) * 100
    }
    
    public init(
        totalFiles: Int,
        processedFiles: Int,
        totalBytes: Int64,
        processedBytes: Int64,
        currentFile: String,
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
}

/// Progress information for a Restic restore operation
public struct ResticRestoreProgress: Codable, Equatable {
    public let totalFiles: Int
    public let processedFiles: Int
    public let totalBytes: Int64
    public let processedBytes: Int64
    public let currentFile: String
    public let startTime: Date
    public let updatedAt: Date
    
    public var percentComplete: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(processedBytes) / Double(totalBytes) * 100
    }
    
    public init(
        totalFiles: Int,
        processedFiles: Int,
        totalBytes: Int64,
        processedBytes: Int64,
        currentFile: String,
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
}

/// Progress information for a Restic mount operation
public struct ResticMountProgress: Codable, Equatable {
    public let status: String
    public let mountPoint: URL
    public let startTime: Date
    public let updatedAt: Date
    
    public init(
        status: String,
        mountPoint: URL,
        startTime: Date,
        updatedAt: Date
    ) {
        self.status = status
        self.mountPoint = mountPoint
        self.startTime = startTime
        self.updatedAt = updatedAt
    }
}

/// Represents the JSON response from restic backup command
struct ResticBackupResponse: Codable {
    let messageType: String
    let filesNew: Int
    let filesChanged: Int
    let filesUnmodified: Int
    let dataBlobs: Int
    let treeBlobs: Int
    let dataMiBs: Double
    let treeMiBs: Double
    let currentFile: String
    let totalFiles: Int
    let filesDone: Int
    let totalBytes: Int64
    let bytesDone: Int64
    let errorCount: Int
    
    enum CodingKeys: String, CodingKey {
        case messageType = "message_type"
        case filesNew = "files_new"
        case filesChanged = "files_changed"
        case filesUnmodified = "files_unmodified"
        case dataBlobs = "data_blobs"
        case treeBlobs = "tree_blobs"
        case dataMiBs = "data_added"
        case treeMiBs = "total_files_processed"
        case currentFile = "current_files"
        case totalFiles = "total_files"
        case filesDone = "files_done"
        case totalBytes = "total_bytes"
        case bytesDone = "bytes_done"
        case errorCount = "error_count"
    }
    
    func toBackupProgress(startTime: Date) -> ResticBackupProgress {
        return ResticBackupProgress(
            totalFiles: totalFiles,
            processedFiles: filesDone,
            totalBytes: totalBytes,
            processedBytes: bytesDone,
            currentFile: currentFile,
            startTime: startTime,
            updatedAt: Date()
        )
    }
}
