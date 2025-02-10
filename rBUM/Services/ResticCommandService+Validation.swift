import Core
import Foundation

/// Extension for core validation methods in ResticCommandService
///
/// This extension provides fundamental validation methods for repository operations,
/// focusing on repository configuration, credentials, and key file validation.
/// It serves as the foundation for all repository-related validations.
extension ResticCommandService {
    /// Validates repository configuration and accessibility
    ///
    /// This method performs comprehensive validation of a repository:
    /// - Validates the repository path exists and is accessible
    /// - Checks repository credentials
    /// - Verifies key file if present
    ///
    /// - Parameter repository: The repository to validate
    ///
    /// - Throws:
    ///   - `ValidationError.emptyRepositoryPath` if the repository path is empty
    ///   - `ValidationError.repositoryNotFound` if the repository doesn't exist
    ///   - `ValidationError.repositoryNotAccessible` if the repository cannot be accessed
    ///   - Other validation errors from credential or key file validation
    func validateRepository(_ repository: Repository) throws {
        // Validate repository path
        guard !repository.path.isEmpty else {
            throw ValidationError.emptyRepositoryPath
        }

        let url = URL(fileURLWithPath: repository.path)

        // Check if repository exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.repositoryNotFound(path: repository.path)
        }

        // Check if repository is accessible
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ValidationError.repositoryNotAccessible(path: repository.path)
        }

        // Validate repository credentials
        try validateCredentials(repository.credentials)
    }

    /// Validates repository credentials
    ///
    /// This method ensures that:
    /// - The repository password is not empty
    /// - The key file is valid if one is provided
    ///
    /// - Parameter credentials: The repository credentials to validate
    ///
    /// - Throws:
    ///   - `ValidationError.emptyPassword` if the password is empty
    ///   - Other validation errors from key file validation if a key file is present
    private func validateCredentials(_ credentials: RepositoryCredentials) throws {
        // Validate repository password
        guard !credentials.password.isEmpty else {
            throw ValidationError.emptyPassword
        }

        // Validate key file if provided
        if let keyFile = credentials.keyFile {
            try validateKeyFile(keyFile)
        }
    }

    /// Validates a repository key file
    ///
    /// This method performs comprehensive validation of a key file:
    /// - Checks that the key file path is not empty
    /// - Verifies that the key file exists
    /// - Ensures the key file is accessible
    /// - Validates the key file size (must be > 0 and <= 1MB)
    ///
    /// - Parameter path: Path to the key file
    ///
    /// - Throws:
    ///   - `ValidationError.emptyKeyFilePath` if the key file path is empty
    ///   - `ValidationError.keyFileNotFound` if the key file doesn't exist
    ///   - `ValidationError.keyFileNotAccessible` if the key file cannot be accessed
    ///   - `ValidationError.emptyKeyFile` if the key file is empty
    ///   - `ValidationError.keyFileTooLarge` if the key file exceeds 1MB
    private func validateKeyFile(_ path: String) throws {
        guard !path.isEmpty else {
            throw ValidationError.emptyKeyFilePath
        }

        let url = URL(fileURLWithPath: path)

        // Check if key file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.keyFileNotFound(path: path)
        }

        // Check if key file is accessible
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ValidationError.keyFileNotAccessible(path: path)
        }

        // Check key file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        guard fileSize > 0 else {
            throw ValidationError.emptyKeyFile
        }

        guard fileSize <= 1024 * 1024 else { // 1MB max
            throw ValidationError.keyFileTooLarge
        }
    }
}

// MARK: - Validation Errors

/// Errors that can occur during validation operations
///
/// This enum defines all possible validation errors that can occur during
/// repository operations, including:
/// - Repository validation errors
/// - Credential validation errors
/// - Key file validation errors
/// - Path validation errors
/// - Tag validation errors
/// - Exclude pattern validation errors
enum ValidationError: LocalizedError {
    // Repository errors
    case emptyRepositoryPath
    case repositoryNotFound(path: String)
    case repositoryNotAccessible(path: String)

    // Credential errors
    case emptyPassword
    case emptyKeyFilePath
    case keyFileNotFound(path: String)
    case keyFileNotAccessible(path: String)
    case emptyKeyFile
    case keyFileTooLarge

    // Snapshot errors
    case invalidSnapshotId
    case snapshotNotFound(id: String)

    // Path errors
    case emptyPath
    case pathNotFound(path: String)
    case pathNotAccessible(path: String)
    case invalidPathFormat(path: String)
    case pathTooLong(path: String)

    // Tag errors
    case emptyTag
    case invalidTagFormat(tag: String)

    // Exclude pattern errors
    case emptyExcludePattern
    case invalidExcludePattern(pattern: String)
    case excludePatternTooLong(pattern: String)

    /// A localized message describing the error
    var errorDescription: String? {
        switch self {
        case .emptyRepositoryPath:
            "Repository path cannot be empty"
        case let .repositoryNotFound(path):
            "Repository not found at path: \(path)"
        case let .repositoryNotAccessible(path):
            "Repository is not accessible at path: \(path)"
        case .emptyPassword:
            "Repository password cannot be empty"
        case .emptyKeyFilePath:
            "Key file path cannot be empty"
        case let .keyFileNotFound(path):
            "Key file not found at path: \(path)"
        case let .keyFileNotAccessible(path):
            "Key file is not accessible at path: \(path)"
        case .emptyKeyFile:
            "Key file is empty"
        case .keyFileTooLarge:
            "Key file is too large (max 1MB)"
        case .invalidSnapshotId:
            "Invalid snapshot ID"
        case let .snapshotNotFound(id):
            "Snapshot not found with ID: \(id)"
        case .emptyPath:
            "Path cannot be empty"
        case let .pathNotFound(path):
            "Path not found: \(path)"
        case let .pathNotAccessible(path):
            "Path is not accessible: \(path)"
        case let .invalidPathFormat(path):
            "Path contains invalid characters: \(path)"
        case let .pathTooLong(path):
            "Path is too long: \(path)"
        case .emptyTag:
            "Tag cannot be empty"
        case let .invalidTagFormat(tag):
            "Tag contains invalid characters: \(tag)"
        case .emptyExcludePattern:
            "Exclude pattern cannot be empty"
        case let .invalidExcludePattern(pattern):
            "Exclude pattern contains invalid characters: \(pattern)"
        case let .excludePatternTooLong(pattern):
            "Exclude pattern is too long: \(pattern)"
        }
    }
}
