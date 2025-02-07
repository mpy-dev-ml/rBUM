//
//  RepositoryStatus.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
/// Model representing the status of a repository after a check operation
struct RepositoryStatus: Codable, Equatable {
    /// Whether the repository is valid
    let isValid: Bool

    /// Whether all pack files are complete and valid
    let packsValid: Bool

    /// Whether all index files are complete and valid
    let indexValid: Bool

    /// Whether all snapshots are complete and valid
    let snapshotsValid: Bool

    /// Any errors encountered during the check
    let errors: [String]

    /// Statistics about the repository
    let stats: RepositoryStats

    /// Repository statistics
    struct RepositoryStats: Codable, Equatable {
        /// Total size of the repository in bytes
        let totalSize: UInt64

        /// Number of pack files
        let packFiles: UInt

        /// Number of snapshots
        let snapshots: UInt

        private enum CodingKeys: String, CodingKey {
            case totalSize = "total_size"
            case packFiles = "pack_files"
            case snapshots
        }
    }

    private enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case packsValid = "packs_valid"
        case indexValid = "index_valid"
        case snapshotsValid = "snapshots_valid"
        case errors
        case stats
    }
}
