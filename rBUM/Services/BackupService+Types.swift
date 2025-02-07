import Core
import Foundation

// MARK: - Backup Types

extension BackupService {
    /// Represents possible errors that can occur during backup operations
    public enum BackupError: LocalizedError {
        case invalidRepository
        case backupFailed
        case restoreFailed
        case snapshotListFailed
        case sourceNotFound
        case destinationNotFound
        case insufficientSpace
        case sourceAccessDenied
        case destinationAccessDenied
        case executionFailed(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidRepository:
                "Invalid repository configuration"
            case .backupFailed:
                "Failed to create backup"
            case .restoreFailed:
                "Failed to restore from snapshot"
            case .snapshotListFailed:
                "Failed to list snapshots"
            case .sourceNotFound:
                "Source directory not found"
            case .destinationNotFound:
                "Destination directory not found"
            case .insufficientSpace:
                "Insufficient space available for backup"
            case .sourceAccessDenied:
                "Access denied to source directory"
            case .destinationAccessDenied:
                "Access denied to destination directory"
            case .executionFailed(let error):
                "Backup execution failed: \(error.localizedDescription)"
            }
        }
    }

    /// Configuration for a backup operation
    struct BackupConfiguration {
        let source: URL
        let destination: URL
        let excludes: [String]
        let tags: [String]
    }

    /// Represents a backup operation in progress
    struct BackupOperation {
        let id: UUID
        let source: URL
        let destination: URL
        let excludes: [String]
        let tags: [String]
        let startTime: Date
    }

    /// Status of a backup result
    enum BackupResultStatus {
        case completed
        case failed
    }

    /// Result of a backup operation
    struct BackupResult {
        let operationId: UUID
        let status: BackupResultStatus
        let startTime: Date
        let endTime: Date
        let duration: TimeInterval
        let error: Error?
    }

    /// Source of a backup
    struct BackupSource {
        let url: URL
        let metadata: [String: String]?
    }

    /// Data associated with a backup
    struct BackupData {
        let source: BackupSource
        let timestamp: Date
        let files: [URL]
        let totalSize: UInt64
        let metadata: [String: String]
    }

    /// Filter for backup operations
    enum BackupFilter {
        case exclude(String)
        case include(String)
        case `extension`(String)
        case size(SizeComparison, UInt64)
        case date(DateComparison, Date)
    }

    /// Size comparison operators
    enum SizeComparison {
        case lessThan
        case greaterThan
        case equalTo
    }

    /// Date comparison operators
    enum DateComparison {
        case before
        case after
        case on
    }

    /// Status of a backup operation
    enum BackupOperationStatus {
        case inProgress
        case completed
        case failed
    }
}
