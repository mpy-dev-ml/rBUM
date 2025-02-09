import Foundation

/// Validator for BackupConfiguration
enum BackupConfigurationValidator {
    /// Validates a backup configuration
    ///
    /// This method checks:
    /// 1. Repository URL is valid and accessible
    /// 2. Source paths are valid and accessible
    /// 3. Exclusion patterns are valid
    /// 4. Schedule configuration is valid
    ///
    /// - Parameter config: The configuration to validate
    /// - Returns: An error message if invalid, nil if valid
    static func validate(_ config: BackupConfiguration) -> String? {
        if let error = validateRepository(config.repositoryURL) {
            return error
        }
        
        if let error = validateSourcePaths(config.sourcePaths) {
            return error
        }
        
        if let error = validateExclusionPatterns(config.exclusionPatterns) {
            return error
        }
        
        if let error = validateSchedule(config.scheduleConfiguration) {
            return error
        }
        
        return nil
    }
    
    /// Validates the repository URL
    private static func validateRepository(_ url: URL?) -> String? {
        guard let url = url else {
            return "Repository URL is required"
        }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            return "Repository path does not exist"
        }
        
        return nil
    }
    
    /// Validates source paths
    private static func validateSourcePaths(_ paths: [URL]) -> String? {
        if paths.isEmpty {
            return "At least one source path is required"
        }
        
        let nonExistentPath = paths.first { !FileManager.default.fileExists(atPath: $0.path) }
        if let path = nonExistentPath {
            return "Source path does not exist: \(path.path)"
        }
        
        return nil
    }
    
    /// Validates exclusion patterns
    private static func validateExclusionPatterns(_ patterns: [ExclusionPattern]) -> String? {
        for pattern in patterns {
            if pattern.pattern.isEmpty {
                return "Exclusion pattern cannot be empty"
            }
            
            if pattern.type == .regex {
                if let error = validateRegexPattern(pattern.pattern) {
                    return error
                }
            }
        }
        
        return nil
    }
    
    /// Validates a regex pattern
    private static func validateRegexPattern(_ pattern: String) -> String? {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return "Invalid regex pattern: \(pattern)"
        }
    }
    
    /// Validates schedule configuration
    private static func validateSchedule(_ schedule: ScheduleConfiguration?) -> String? {
        guard let schedule = schedule else { return nil }
        
        if schedule.interval <= 0 {
            return "Schedule interval must be greater than 0"
        }
        
        if schedule.retentionDays <= 0 {
            return "Retention days must be greater than 0"
        }
        
        return nil
    }
}
