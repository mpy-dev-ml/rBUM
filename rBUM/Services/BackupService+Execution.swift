import Core
import Foundation

extension BackupService {
    // MARK: - Backup Execution

    /// Executes a backup operation.
    ///
    /// - Parameters:
    ///   - source: The source URL for the backup
    ///   - destination: The destination repository
    ///   - options: Backup options
    /// - Throws: BackupError if backup fails
    func executeBackup(
        source: URL,
        destination: Repository,
        options: BackupOptions
    ) async throws {
        // Create operation ID
        let operationId = UUID()

        do {
            // Start operation
            try await startBackupOperation(
                operationId,
                source: source,
                destination: destination,
                options: options
            )

            // Validate prerequisites
            try await validateBackupPrerequisites(
                source: source,
                destination: destination,
                options: options
            )

            // Prepare backup
            let (environment, arguments) = try await prepareBackup(
                source: source,
                destination: destination,
                options: options
            )

            // Execute backup
            try await resticService.backup(
                source: source,
                destination: destination,
                environment: environment,
                arguments: arguments
            )

            // Complete operation
            try await completeBackupOperation(operationId, success: true)

        } catch {
            // Handle failure
            try await completeBackupOperation(operationId, success: false, error: error)
            throw error
        }
    }

    /// Prepares a backup operation.
    ///
    /// - Parameters:
    ///   - source: The source URL for the backup
    ///   - destination: The destination repository
    ///   - options: Backup options
    /// - Returns: Tuple containing environment variables and command arguments
    /// - Throws: BackupError if preparation fails
    private func prepareBackup(
        source: URL,
        destination: Repository,
        options: BackupOptions
    ) async throws -> ([String: String], [String]) {
        // Get repository credentials
        let credentials = try await credentialsService.getCredentials(for: destination)

        // Create environment variables
        var environment = [String: String]()
        environment["RESTIC_PASSWORD"] = credentials.password
        environment["RESTIC_REPOSITORY"] = destination.path

        // Create command arguments
        var arguments = [String]()

        // Add compression options
        if options.compression {
            arguments.append("--compression")
            arguments.append("\(options.compressionLevel)")
        }

        // Add encryption options
        if options.encryption {
            arguments.append("--encryption")
            if let key = options.encryptionKey {
                arguments.append("--key")
                arguments.append(key)
            }
        }

        // Add chunk size option
        arguments.append("--pack-size")
        arguments.append("\(options.chunkSize)")

        // Add source path
        arguments.append(source.path)

        return (environment, arguments)
    }

    /// Scans a source directory for files to backup.
    ///
    /// - Parameter url: The directory URL to scan
    /// - Returns: Array of file URLs
    /// - Throws: BackupError if scan fails
    private func scanSourceDirectory(_ url: URL) async throws -> [URL] {
        var files: [URL] = []

        if try await fileManager.isDirectory(at: url) {
            // Recursively scan directory
            let contents = try await fileManager.contentsOfDirectory(at: url)

            for item in contents {
                if try await fileManager.isDirectory(at: item) {
                    files += try await scanSourceDirectory(item)
                } else {
                    files.append(item)
                }
            }
        } else {
            files.append(url)
        }

        return files
    }

    /// Creates a backup manifest.
    ///
    /// - Parameters:
    ///   - source: The source URL for the backup
    ///   - destination: The destination repository
    ///   - options: Backup options
    /// - Returns: The created manifest
    /// - Throws: BackupError if manifest creation fails
    private func createBackupManifest(
        source: URL,
        destination: Repository,
        options: BackupOptions
    ) async throws -> BackupManifest {
        // Scan source directory
        let files = try await scanSourceDirectory(source)

        // Calculate total size
        var totalSize: UInt64 = 0
        for file in files {
            totalSize += try await fileManager.size(of: file)
        }

        // Create manifest
        return BackupManifest(
            id: UUID(),
            source: source,
            destination: destination,
            files: files,
            totalSize: totalSize,
            options: options,
            timestamp: Date()
        )
    }
}
