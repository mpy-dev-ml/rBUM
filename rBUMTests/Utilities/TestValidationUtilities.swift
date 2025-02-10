import Core
import Foundation

/// Utilities for validating test conditions and results
enum TestValidationUtilities {
    /// Validates that a repository exists and has the expected structure
    /// - Parameter url: The URL of the repository to validate
    /// - Returns: True if the repository is valid
    static func validateRepository(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        let requiredFiles = [
            "config",
            "data",
            "index",
            "keys",
            "snapshots",
        ]

        return requiredFiles.allSatisfy { file in
            FileManager.default.fileExists(
                atPath: url.appendingPathComponent(file).path
            )
        }
    }

    /// Validates that a backup operation completed successfully
    /// - Parameters:
    ///   - sourceURL: The source directory URL
    ///   - backupURL: The backup destination URL
    /// - Returns: True if the backup is valid
    static func validateBackup(
        source sourceURL: URL,
        backup backupURL: URL
    ) throws -> Bool {
        // Get source files
        let sourceFiles = try FileManager.default.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        // Get backup files
        let backupFiles = try FileManager.default.contentsOfDirectory(
            at: backupURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        // Compare file counts
        guard sourceFiles.count == backupFiles.count else {
            return false
        }

        // Compare file contents
        for sourceFile in sourceFiles {
            let fileName = sourceFile.lastPathComponent
            let backupFile = backupURL.appendingPathComponent(fileName)

            guard FileManager.default.fileExists(atPath: backupFile.path) else {
                return false
            }

            let sourceData = try Data(contentsOf: sourceFile)
            let backupData = try Data(contentsOf: backupFile)

            guard sourceData == backupData else {
                return false
            }
        }

        return true
    }

    /// Validates that a file has the expected content
    /// - Parameters:
    ///   - url: The URL of the file to validate
    ///   - expectedContent: The expected content of the file
    /// - Returns: True if the file content matches
    static func validateFileContent(
        at url: URL,
        matches expectedContent: String
    ) throws -> Bool {
        let actualContent = try String(
            contentsOf: url,
            encoding: .utf8
        )
        return actualContent == expectedContent
    }
}
