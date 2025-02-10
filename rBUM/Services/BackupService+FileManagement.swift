import Core
import Foundation

/// Extension providing file management capabilities for BackupService
extension BackupService {
    // MARK: - File Management

    /// Scans a directory recursively to collect all file URLs.
    ///
    /// - Parameter url: The URL of the directory to scan
    /// - Returns: Array of file URLs found in the directory
    func scanSourceDirectory(_ url: URL) async throws -> [URL] {
        var files: [URL] = []

        if try await fileManager.isDirectory(at: url) {
            // Recursively scan directory
            let contents = try await fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for fileURL in contents {
                if try await fileManager.isDirectory(at: fileURL) {
                    // Recursively scan subdirectories
                    try await files.append(contentsOf: scanSourceDirectory(fileURL))
                } else {
                    files.append(fileURL)
                }
            }
        } else {
            files.append(url)
        }

        return files
    }

    /// Validates file access permissions.
    ///
    /// - Parameter url: The URL to validate
    /// - Returns: Boolean indicating whether access is valid
    func validateFileAccess(at url: URL) async throws -> Bool {
        // Check if file exists
        guard try await fileManager.fileExists(at: url) else {
            throw BackupError.fileNotFound(url.path)
        }

        // Check read permission
        guard try await fileManager.isReadable(at: url) else {
            throw BackupError.accessDenied(url.path)
        }

        return true
    }

    /// Validates a backup destination.
    ///
    /// - Parameter url: The URL of the backup destination
    /// - Returns: Boolean indicating whether the destination is valid
    func validateBackupDestination(_ url: URL) async throws -> Bool {
        // Check if destination exists
        guard try await fileManager.fileExists(at: url) else {
            // Try to create destination
            try await fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        }

        // Check write permission
        guard try await fileManager.isWritable(at: url) else {
            throw BackupError.accessDenied(url.path)
        }

        return true
    }

    /// Cleans up temporary files created during backup.
    ///
    /// - Parameter url: The URL of the temporary directory to clean
    func cleanupTemporaryFiles(at url: URL) async throws {
        guard try await fileManager.fileExists(at: url) else {
            return
        }

        try await fileManager.removeItem(at: url)
    }
}
