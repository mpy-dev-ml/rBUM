import Foundation

/// Represents a pattern for excluding files and directories from backup
public struct ExclusionPattern: Codable, Equatable, Hashable {
    /// Category of exclusion pattern
    public enum Category: String, Codable, CaseIterable {
        /// System-related files (logs, caches, temporary files)
        case system
        /// User-defined exclusions
        case user
        /// Temporary exclusions that may be removed later
        case temporary
        /// Security-related exclusions
        case security
        /// Performance-related exclusions
        case performance
        /// Custom category
        case custom(String)

        /// Whether this category inherits to subdirectories by default
        public var inheritsByDefault: Bool {
            switch self {
            case .system,
                 .security: true
            case .user,
                 .temporary,
                 .performance,
                 .custom: false
            }
        }

        /// Display name for the category
        public var displayName: String {
            switch self {
            case .system: "System"
            case .user: "User"
            case .temporary: "Temporary"
            case .security: "Security"
            case .performance: "Performance"
            case let .custom(name): "Custom: \(name)"
            }
        }

        /// Validation rules for this category
        public var validationRules: ValidationRules {
            switch self {
            case .system:
                ValidationRules(
                    allowedPatternTypes: [.glob, .exact],
                    requiresDirectory: false,
                    maxPatternLength: 100,
                    disallowedPatterns: ["/*", "/**", "*"]
                )
            case .security:
                ValidationRules(
                    allowedPatternTypes: [.exact],
                    requiresDirectory: false,
                    maxPatternLength: 255,
                    disallowedPatterns: ["/*", "/**", "*"]
                )
            case .performance:
                ValidationRules(
                    allowedPatternTypes: [.glob, .exact],
                    requiresDirectory: true,
                    maxPatternLength: 100,
                    disallowedPatterns: []
                )
            case .user,
                 .temporary,
                 .custom:
                ValidationRules(
                    allowedPatternTypes: [.glob, .exact, .regex],
                    requiresDirectory: false,
                    maxPatternLength: 255,
                    disallowedPatterns: []
                )
            }
        }
    }

    /// Type of pattern matching to use
    public enum PatternType: String, Codable {
        /// Exact string match
        case exact
        /// Glob pattern (*, ?)
        case glob
        /// Regular expression
        case regex
    }

    /// Rules for validating patterns
    public struct ValidationRules {
        /// Allowed pattern types
        public let allowedPatternTypes: Set<PatternType>
        /// Whether the pattern must be for directories
        public let requiresDirectory: Bool
        /// Maximum length of the pattern
        public let maxPatternLength: Int
        /// Patterns that are not allowed
        public let disallowedPatterns: Set<String>
    }

    /// Priority level for exclusion patterns
    public enum Priority: Int, Codable, Comparable {
        /// Highest priority, always applied first
        case critical = 1000
        /// High priority patterns
        case high = 100
        /// Normal priority patterns
        case normal = 0
        /// Low priority patterns
        case low = -100
        /// Custom priority level
        case custom(Int)

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        /// Raw value for sorting
        public var rawValue: Int {
            switch self {
            case .critical: 1000
            case .high: 100
            case .normal: 0
            case .low: -100
            case let .custom(value): value
            }
        }

        /// Description of the priority level
        public var description: String {
            switch self {
            case .critical: "Critical"
            case .high: "High"
            case .normal: "Normal"
            case .low: "Low"
            case let .custom(value): "Custom(\(value))"
            }
        }
    }

    /// The pattern to match against
    public let pattern: String

    /// Type of pattern matching to use
    public let patternType: PatternType

    /// Whether this is a directory pattern
    public let isDirectory: Bool

    /// Priority of this pattern
    public let priority: Priority

    /// Category of this pattern
    public let category: Category

    /// Whether this pattern should inherit to subdirectories
    public let inheritsToSubdirectories: Bool

    /// Group this pattern belongs to, if any
    public let groupId: UUID?

    /// Create a new exclusion pattern
    /// - Parameters:
    ///   - pattern: The pattern to match against
    ///   - patternType: Type of pattern matching to use
    ///   - isDirectory: Whether this is a directory pattern
    ///   - priority: Priority of this pattern
    ///   - category: Category of this pattern
    ///   - inheritsToSubdirectories: Whether this pattern should inherit to subdirectories
    ///   - groupId: ID of the group this pattern belongs to, if any
    public init(
        pattern: String,
        patternType: PatternType = .glob,
        isDirectory: Bool = false,
        priority: Priority = .normal,
        category: Category = .user,
        inheritsToSubdirectories: Bool? = nil,
        groupId: UUID? = nil
    ) {
        self.pattern = pattern
        self.patternType = patternType
        self.isDirectory = isDirectory
        self.priority = priority
        self.category = category
        self.inheritsToSubdirectories = inheritsToSubdirectories ?? category.inheritsByDefault
        self.groupId = groupId
    }

    /// Validate the pattern
    /// - Throws: ConfigurationError if validation fails
    public func validate() throws {
        guard !pattern.isEmpty else {
            throw ConfigurationError.invalidExclusionPattern("Exclusion pattern cannot be empty")
        }

        // Get validation rules for this category
        let rules = category.validationRules

        // Check pattern type is allowed
        guard rules.allowedPatternTypes.contains(patternType) else {
            let types = rules.allowedPatternTypes.map(\.rawValue)
            let msg = """
            '\(patternType)' not allowed in '\(category.displayName)'.
            Allowed: \(types.joined(separator: ", "))
            """
            throw ConfigurationError.invalidExclusionPattern(msg)
        }

        // Check directory requirement
        if rules.requiresDirectory, !isDirectory {
            throw ConfigurationError.invalidExclusionPattern(
                "Patterns in category '\(category.displayName)' must be directory patterns"
            )
        }

        // Check pattern length
        guard pattern.count <= rules.maxPatternLength else {
            throw ConfigurationError.invalidExclusionPattern(
                "Pattern exceeds maximum length of \(rules.maxPatternLength) characters"
            )
        }

        // Check for disallowed patterns
        guard !rules.disallowedPatterns.contains(pattern) else {
            throw ConfigurationError.invalidExclusionPattern(
                "Pattern '\(pattern)' is not allowed in category '\(category.displayName)'"
            )
        }

        // Ensure pattern doesn't contain invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "<>:|")
        guard pattern.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw ConfigurationError.invalidExclusionPattern(
                "Pattern contains invalid characters: \(pattern)"
            )
        }

        // Validate regex patterns compile
        if patternType == .regex {
            do {
                _ = try NSRegularExpression(pattern: pattern)
            } catch {
                throw ConfigurationError.invalidExclusionPattern(
                    "Invalid regular expression: \(error.localizedDescription)"
                )
            }
        }
    }

    /// Check if a path matches this pattern
    /// - Parameters:
    ///   - path: Path to check
    ///   - parentMatched: Whether a parent directory was matched by this pattern
    /// - Returns: True if the path matches, false otherwise
    public func matches(path: String, parentMatched: Bool = false) -> Bool {
        // If a parent matched and we inherit, it's a match
        if parentMatched, inheritsToSubdirectories {
            return true
        }

        let pathURL = URL(fileURLWithPath: path)

        // If this is a directory pattern and the path isn't a directory, no match
        if isDirectory {
            let isDirectory = (try? pathURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if !isDirectory {
                return false
            }
        }

        // Match based on pattern type
        switch patternType {
        case .exact:
            return path == pattern
        case .glob:
            // Use path.matches() for pattern matching when available in macOS 14+
            // For now, use simple string matching
            if pattern.hasPrefix("*"), pattern.hasSuffix("*") {
                let subpattern = pattern.dropFirst().dropLast()
                return path.contains(subpattern)
            } else if pattern.hasPrefix("*") {
                let suffix = pattern.dropFirst()
                return path.hasSuffix(suffix)
            } else if pattern.hasSuffix("*") {
                let prefix = pattern.dropLast()
                return path.hasPrefix(prefix)
            } else {
                return path == pattern
            }
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            let range = NSRange(path.startIndex ..< path.endIndex, in: path)
            return regex.firstMatch(in: path, range: range) != nil
        }
    }

    /// Get a description of why this pattern matched
    /// - Parameter isInherited: Whether the match was inherited from a parent directory
    /// - Returns: A description of the match
    public func matchDescription(isInherited: Bool = false) -> String {
        let baseDescription = "Excluded by \(category.displayName) pattern '\(pattern)' " +
            "(Priority: \(priority.description))"
        return isInherited ? "\(baseDescription) [Inherited]" : baseDescription
    }

    /// Validates if a path matches this exclusion pattern
    ///
    /// - Parameter path: The path to check
    /// - Returns: A tuple containing whether the path matches and any error that occurred
    public func matches(_ path: String) -> (matches: Bool, error: Error?) {
        switch patternType {
        case .glob:
            matchesGlobPattern(path)
        case .regex:
            matchesRegexPattern(path)
        case .exact:
            (path == pattern, nil)
        }
    }

    /// Matches a path against a glob pattern
    private func matchesGlobPattern(_ path: String) -> (matches: Bool, error: Error?) {
        // Convert glob to regex pattern
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        do {
            let regex = try NSRegularExpression(
                pattern: "^" + regexPattern + "$",
                options: []
            )
            let range = NSRange(location: 0, length: path.utf16.count)
            let matches = regex.matches(in: path, range: range)
            return (!matches.isEmpty, nil)
        } catch {
            return (false, error)
        }
    }

    /// Matches a path against a regex pattern
    private func matchesRegexPattern(_ path: String) -> (matches: Bool, error: Error?) {
        do {
            let regex = try NSRegularExpression(
                pattern: pattern,
                options: []
            )
            let range = NSRange(location: 0, length: path.utf16.count)
            let matches = regex.matches(in: path, range: range)
            return (!matches.isEmpty, nil)
        } catch {
            return (false, error)
        }
    }
}
