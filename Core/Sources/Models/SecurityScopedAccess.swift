import Foundation

/// Manages security-scoped access to files and directories in a thread-safe manner
public struct SecurityScopedAccess: Codable, Equatable {
    /// The URL being accessed
    public let url: URL
    
    /// The security-scoped bookmark data
    private let bookmarkData: Data
    
    /// Whether this bookmark is currently being accessed
    private(set) public var isAccessing: Bool
    
    /// Whether this bookmark was created for a directory
    private let isDirectory: Bool
    
    /// Queue for synchronising access operations
    private static let accessQueue = DispatchQueue(label: "dev.mpy.rbum.securityscoped")
    
    /// Create a new security-scoped access instance
    /// - Parameters:
    ///   - url: The URL to create bookmark for
    ///   - isDirectory: Whether the URL points to a directory
    /// - Throws: SecurityScopedAccessError if bookmark creation fails
    public init(url: URL, isDirectory: Bool = false) throws {
        self.url = url
        self.isAccessing = false
        self.isDirectory = isDirectory
        
        let options: URL.BookmarkCreationOptions = isDirectory 
            ? [.withSecurityScope, .minimalBookmark]
            : .withSecurityScope
            
        do {
            self.bookmarkData = try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw SecurityScopedAccessError.bookmarkCreationFailed(error)
        }
    }
    
    /// Coding keys for Codable conformance
    private enum CodingKeys: String, CodingKey {
        case url
        case bookmarkData
        case isDirectory
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(URL.self, forKey: .url)
        self.bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
        self.isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        self.isAccessing = false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url, forKey: .url)
        try container.encode(bookmarkData, forKey: .bookmarkData)
        try container.encode(isDirectory, forKey: .isDirectory)
    }
    
    /// Start accessing the security-scoped resource in a thread-safe manner
    /// - Throws: SecurityScopedAccessError if access cannot be started
    public mutating func startAccessing() throws {
        try Self.accessQueue.sync {
            guard !isAccessing else { return }
            
            var isStale = false
            do {
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                guard resolvedURL == url else {
                    throw SecurityScopedAccessError.urlMismatch(expected: url, got: resolvedURL)
                }
                
                if isStale {
                    throw SecurityScopedAccessError.staleBookmark(url)
                }
                
                guard resolvedURL.startAccessingSecurityScopedResource() else {
                    throw SecurityScopedAccessError.accessDenied(url)
                }
                
                isAccessing = true
            } catch let error as SecurityScopedAccessError {
                throw error
            } catch {
                throw SecurityScopedAccessError.bookmarkResolutionFailed(error)
            }
        }
    }
    
    /// Stop accessing the security-scoped resource in a thread-safe manner
    public mutating func stopAccessing() {
        Self.accessQueue.sync {
            guard isAccessing else { return }
            url.stopAccessingSecurityScopedResource()
            isAccessing = false
        }
    }
}

/// Errors that can occur when working with security-scoped access
public enum SecurityScopedAccessError: LocalizedError {
    case bookmarkCreationFailed(Error)
    case bookmarkResolutionFailed(Error)
    case accessDenied(URL)
    case urlMismatch(expected: URL, got: URL)
    case staleBookmark(URL)
    
    public var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed(let error):
            return "Failed to create security-scoped bookmark: \(error.localizedDescription)"
        case .bookmarkResolutionFailed(let error):
            return "Failed to resolve security-scoped bookmark: \(error.localizedDescription)"
        case .accessDenied(let url):
            return "Access denied to security-scoped resource at \(url.path)"
        case .urlMismatch(let expected, let got):
            return "URL mismatch when resolving bookmark. Expected: \(expected.path), got: \(got.path)"
        case .staleBookmark(let url):
            return "Stale bookmark detected for resource at \(url.path). Please request access again."
        }
    }
}
