import Core
import Foundation

/// Extension for snapshot validation methods in ResticCommandService
///
/// This extension provides validation methods specifically for snapshot-related operations,
/// including snapshot existence verification, tag validation, and parameter validation.
extension ResticCommandService {
    /// Validates all snapshot-related parameters for restic operations
    ///
    /// This method performs comprehensive validation of parameters used in snapshot operations:
    /// - Validates the repository configuration and accessibility
    /// - Verifies snapshot existence if a snapshot ID is provided
    /// - Validates the backup path if specified
    /// - Checks tag format and content if tags are provided
    ///
    /// - Parameters:
    ///   - repository: The repository to validate
    ///   - snapshot: Optional snapshot to verify
    ///   - path: Optional path to validate
    ///   - tags: Optional array of tags to validate
    ///
    /// - Throws: `ValidationError` if any validation fails
    func validateSnapshotParameters(
        repository: Repository,
        snapshot: ResticSnapshot? = nil,
        path: String? = nil,
        tags: [String]? = nil
    ) throws {
        // Validate repository
        try validateRepository(repository)

        // Validate snapshot if provided
        if let snapshot {
            try validateSnapshot(snapshot, in: repository)
        }

        // Validate path if provided
        if let path {
            try validatePath(path)
        }

        // Validate tags if provided
        if let tags {
            try validateTags(tags)
        }
    }

    /// Validates that a snapshot exists in the specified repository
    ///
    /// This method checks:
    /// - The snapshot ID is not empty
    /// - The snapshot exists in the repository by querying the repository's snapshot list
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot to validate
    ///   - repository: The repository where the snapshot should exist
    ///
    /// - Throws:
    ///   - `ValidationError.invalidSnapshotId` if the snapshot ID is empty
    ///   - `ValidationError.snapshotNotFound` if the snapshot doesn't exist in the repository
    ///   - Other errors that may occur during repository access
    private func validateSnapshot(
        _ snapshot: ResticSnapshot,
        in repository: Repository
    ) throws {
        guard !snapshot.id.isEmpty else {
            throw ValidationError.invalidSnapshotId
        }

        // Check if snapshot exists in repository
        let result = try await runCommand(
            .listSnapshots(repository: repository),
            validateOutput: false
        )

        let snapshots = try JSONDecoder().decode(
            [ResticSnapshot].self,
            from: result.output.data(using: .utf8) ?? Data()
        )

        guard snapshots.contains(where: { $0.id == snapshot.id }) else {
            throw ValidationError.snapshotNotFound(id: snapshot.id)
        }
    }

    /// Validates the format and content of backup tags
    ///
    /// This method ensures that each tag:
    /// - Is not empty
    /// - Contains only valid characters (alphanumeric, hyphens, and underscores)
    /// - Follows the required format pattern
    ///
    /// - Parameter tags: Array of tags to validate
    ///
    /// - Throws:
    ///   - `ValidationError.emptyTag` if any tag is empty
    ///   - `ValidationError.invalidTagFormat` if a tag contains invalid characters
    private func validateTags(_ tags: [String]) throws {
        for tag in tags {
            guard !tag.isEmpty else {
                throw ValidationError.emptyTag
            }

            // Tags should only contain alphanumeric characters, hyphens, and underscores
            let pattern = "^[a-zA-Z0-9-_]+$"
            guard tag.range(of: pattern, options: .regularExpression) != nil else {
                throw ValidationError.invalidTagFormat(tag: tag)
            }
        }
    }
}
