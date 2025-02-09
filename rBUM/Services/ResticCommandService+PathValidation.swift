import Core
import Foundation

/// Extension for path validation methods in ResticCommandService
///
/// This extension provides validation methods for file system paths and exclude patterns,
/// ensuring that paths are valid, accessible, and follow the required format constraints.
extension ResticCommandService {
    /// Validates a file or directory path for backup operations
    ///
    /// This method performs comprehensive validation of a file system path:
    /// - Checks that the path is not empty
    /// - Verifies that the path exists in the file system
    /// - Ensures the path is accessible with current permissions
    /// - Validates the path format and length
    ///
    /// - Parameter path: The file system path to validate
    ///
    /// - Throws:
    ///   - `ValidationError.emptyPath` if the path is empty
    ///   - `ValidationError.pathNotFound` if the path doesn't exist
    ///   - `ValidationError.pathNotAccessible` if the path cannot be accessed
    ///   - `ValidationError.invalidPathFormat` if the path contains invalid characters
    ///   - `ValidationError.pathTooLong` if the path exceeds the maximum length
    func validatePath(_ path: String) throws {
        guard !path.isEmpty else {
            throw ValidationError.emptyPath
        }
        
        let url = URL(fileURLWithPath: path)
        
        // Check if path exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.pathNotFound(path: path)
        }
        
        // Check if path is accessible
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw ValidationError.pathNotAccessible(path: path)
        }
        
        // Check for invalid characters in path
        let invalidCharacters = CharacterSet(charactersIn: "<>:\"|?*")
        guard url.path.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw ValidationError.invalidPathFormat(path: path)
        }
        
        // Check path length
        guard url.path.count <= 4096 else {
            throw ValidationError.pathTooLong(path: path)
        }
    }
    
    /// Validates exclude patterns for backup operations
    ///
    /// This method validates an array of exclude patterns, ensuring each pattern:
    /// - Is not empty
    /// - Contains only valid characters
    /// - Does not exceed the maximum length
    ///
    /// Exclude patterns are used to specify files or directories that should be
    /// excluded from backup operations. They support glob patterns and regular expressions
    /// depending on the context.
    ///
    /// - Parameter patterns: Array of exclude patterns to validate
    ///
    /// - Throws:
    ///   - `ValidationError.emptyExcludePattern` if any pattern is empty
    ///   - `ValidationError.invalidExcludePattern` if a pattern contains invalid characters
    ///   - `ValidationError.excludePatternTooLong` if a pattern exceeds the maximum length
    func validateExcludePatterns(_ patterns: [String]) throws {
        for pattern in patterns {
            guard !pattern.isEmpty else {
                throw ValidationError.emptyExcludePattern
            }
            
            // Check for invalid characters in pattern
            let invalidCharacters = CharacterSet(charactersIn: "<>:\"|")
            guard pattern.rangeOfCharacter(from: invalidCharacters) == nil else {
                throw ValidationError.invalidExcludePattern(pattern: pattern)
            }
            
            // Check pattern length
            guard pattern.count <= 1024 else {
                throw ValidationError.excludePatternTooLong(pattern: pattern)
            }
        }
    }
}
