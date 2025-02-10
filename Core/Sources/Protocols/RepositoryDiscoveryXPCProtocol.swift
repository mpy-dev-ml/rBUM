import Foundation

/// XPC protocol for repository discovery operations
@objc public protocol RepositoryDiscoveryXPCProtocol {
    /// Scans a location for Restic repositories
    /// - Parameters:
    ///   - url: The URL to scan
    ///   - recursive: Whether to scan subdirectories
    ///   - reply: Completion handler with discovered repositories or error
    @objc func scanLocation(_ url: URL, recursive: Bool, reply: @escaping ([URL]?, Error?) -> Void)

    /// Verifies if a location contains a valid Restic repository
    /// - Parameters:
    ///   - url: The URL to verify
    ///   - reply: Completion handler with verification result or error
    @objc func verifyRepository(at url: URL, reply: @escaping (Bool, Error?) -> Void)

    /// Retrieves repository metadata from a location
    /// - Parameters:
    ///   - url: The URL to check
    ///   - reply: Completion handler with metadata dictionary or error
    @objc func getRepositoryMetadata(at url: URL, reply: @escaping ([String: Any]?, Error?) -> Void)

    /// Indexes a repository for searching
    /// - Parameters:
    ///   - url: The URL to index
    ///   - reply: Completion handler with optional error
    @objc func indexRepository(at url: URL, reply: @escaping (Error?) -> Void)

    /// Cancels ongoing operations
    @objc func cancelOperations()
}
