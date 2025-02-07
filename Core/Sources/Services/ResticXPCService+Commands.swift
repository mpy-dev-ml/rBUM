import Foundation
import os.log

// MARK: - ResticServiceProtocol Implementation

@available(macOS 13.0, *)
public extension ResticXPCService {
    /// Initializes a new Restic repository at the specified URL
    /// - Parameter url: The URL where the repository should be initialized
    /// - Throws: ProcessError if the initialization fails
    func initializeRepository(at url: URL) async throws {
        logger.info(
            "Initializing repository at \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        // Initialize repository
        _ = try await executeCommand(
            "init",
            arguments: [],
            environment: [:],
            workingDirectory: url.path,
            bookmarks: nil,
            retryCount: 3
        )
    }

    /// Creates a backup from the source directory to the destination repository
    /// - Parameters:
    ///   - source: The URL of the directory to backup
    ///   - destination: The URL of the Restic repository
    /// - Throws: ProcessError if the backup operation fails
    func backup(from source: URL, to destination: URL) async throws {
        logger.info(
            "Backing up \(source.path) to \(destination.path)",
            file: #file,
            function: #function,
            line: #line
        )

        let result = try await executeCommand(
            "backup",
            arguments: [source.path],
            environment: [:],
            workingDirectory: destination.path,
            bookmarks: nil,
            retryCount: 3
        )

        if !result.succeeded {
            throw ProcessError.executionFailed("Backup command failed with exit code: \(result.exitCode)")
        }
    }

    /// Lists all snapshots in the repository
    /// - Returns: An array of snapshot IDs
    /// - Throws: ProcessError if the list operation fails
    func listSnapshots() async throws -> [String] {
        let result = try await executeCommand(
            "restic",
            arguments: ["snapshots", "--json"],
            environment: [:],
            workingDirectory: "/",
            bookmarks: nil
        )
        // Parse JSON output to extract snapshot IDs
        // This is a simplified implementation
        return result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }

    /// Restores data from a repository snapshot to a destination directory
    /// - Parameters:
    ///   - source: The URL of the Restic repository containing the snapshot
    ///   - destination: The URL where the data should be restored
    /// - Throws: ProcessError if the restore operation fails
    func restore(from source: URL, to destination: URL) async throws {
        logger.info(
            "Restoring from \(source.path) to \(destination.path)",
            file: #file,
            function: #function,
            line: #line
        )

        let result = try await executeCommand(
            "restore",
            arguments: ["latest", "--target", destination.path],
            environment: [:],
            workingDirectory: source.path,
            bookmarks: nil,
            retryCount: 3
        )

        if !result.succeeded {
            throw ProcessError.executionFailed("Restore command failed with exit code: \(result.exitCode)")
        }
    }
}
