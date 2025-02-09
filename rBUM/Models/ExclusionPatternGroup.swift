import Foundation

/// Represents a group of related exclusion patterns
public struct ExclusionPatternGroup: Codable, Equatable, Identifiable {
    /// Unique identifier for the group
    public let id: UUID
    
    /// Name of the group
    public let name: String
    
    /// Description of what this group excludes
    public let description: String?
    
    /// Whether this group is enabled
    public let enabled: Bool
    
    /// Patterns in this group
    public let patterns: Set<ExclusionPattern>
    
    /// Create a new pattern group
    /// - Parameters:
    ///   - id: Unique identifier for the group
    ///   - name: Name of the group
    ///   - description: Description of what this group excludes
    ///   - enabled: Whether this group is enabled
    ///   - patterns: Patterns in this group
    /// - Throws: ConfigurationError if validation fails
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        enabled: Bool = true,
        patterns: Set<ExclusionPattern>
    ) throws {
        // Validate group name
        guard !name.isEmpty else {
            throw ConfigurationError.invalidPatternGroup("Pattern group name cannot be empty")
        }
        
        // Validate patterns
        guard !patterns.isEmpty else {
            throw ConfigurationError.invalidPatternGroup("Pattern group must contain at least one pattern")
        }
        
        // Validate each pattern
        try patterns.forEach { pattern in
            try pattern.validate()
        }
        
        self.id = id
        self.name = name
        self.description = description
        self.enabled = enabled
        self.patterns = patterns
    }
    
    /// Validate the pattern group
    /// - Throws: ConfigurationError if validation fails
    public func validate() throws {
        // Validate each pattern
        try patterns.forEach { pattern in
            try pattern.validate()
        }
    }
}
