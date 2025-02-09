import Foundation

/// Manages security-scoped resource access for sandboxed applications
public struct SecurityScopedAccess: Codable {
    /// URL to access
    public let url: URL
    
    /// Whether this is a directory
    public let isDirectory: Bool
    
    /// Current access state
    private(set) public var isAccessing: Bool = false
    
    /// Create new security-scoped access
    /// - Parameters:
    ///   - url: URL to access
    ///   - isDirectory: Whether this is a directory
    /// - Throws: ConfigurationError if access cannot be created
    public init(url: URL, isDirectory: Bool) throws {
        self.url = url
        self.isDirectory = isDirectory
    }
    
    /// Start accessing the resource
    /// - Throws: ConfigurationError if access cannot be started
    public mutating func startAccessing() throws {
        guard !isAccessing else { return }
        
        guard url.startAccessingSecurityScopedResource() else {
            throw ConfigurationError.sourceAccessFailed(
                "Failed to access \(url.path)"
            )
        }
        
        isAccessing = true
    }
    
    /// Stop accessing the resource
    public mutating func stopAccessing() {
        guard isAccessing else { return }
        url.stopAccessingSecurityScopedResource()
        isAccessing = false
    }
}
