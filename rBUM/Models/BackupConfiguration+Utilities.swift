import Foundation

extension BackupConfiguration {
    /// Utility functions for managing backup configurations
    enum Utilities {
        /// Generates a unique identifier for a backup configuration
        ///
        /// The identifier is based on:
        /// - Repository URL
        /// - Source paths
        /// - Exclusion patterns
        /// - Schedule configuration
        ///
        /// - Parameter config: The configuration to generate an ID for
        /// - Returns: A unique identifier string
        static func generateIdentifier(for config: BackupConfiguration) -> String {
            var components = [String]()

            // Add repository path
            if let repoURL = config.repositoryURL {
                components.append(repoURL.path)
            }

            // Add source paths
            components.append(contentsOf: config.sourcePaths.map(\.path))

            // Add exclusion patterns
            components.append(contentsOf: config.exclusionPatterns.map(\.pattern))

            // Add schedule info if present
            if let schedule = config.scheduleConfiguration {
                components.append("\(schedule.interval)")
                components.append("\(schedule.retentionDays)")
            }

            // Join and hash components
            let joined = components.joined(separator: "|")
            let data = joined.data(using: .utf8) ?? Data()
            return data.base64EncodedString()
        }

        /// Creates a deep copy of a backup configuration
        ///
        /// - Parameter config: The configuration to copy
        /// - Returns: A new instance with the same values
        static func copy(_ config: BackupConfiguration) -> BackupConfiguration {
            let copy = BackupConfiguration()
            copy.repositoryURL = config.repositoryURL
            copy.sourcePaths = config.sourcePaths
            copy.exclusionPatterns = config.exclusionPatterns
            copy.scheduleConfiguration = config.scheduleConfiguration
            return copy
        }
    }
}
