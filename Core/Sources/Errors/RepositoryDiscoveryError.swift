import Foundation

/// Errors that can occur during repository discovery
///
/// This type defines the various errors that can occur during the repository
/// discovery process. It provides specific error cases for common failure modes,
/// along with localised descriptions and recovery suggestions.
///
/// ## Overview
/// The error cases cover the main categories of failures:
/// - Access problems (permissions, sandbox restrictions)
/// - Invalid repository structure
/// - Verification failures
/// - General discovery errors
///
/// Each error case includes contextual information to help diagnose and resolve
/// the issue, such as the affected URL or specific error messages.
///
/// ## Example Usage
/// ```swift
/// do {
///     try await service.scanLocation(url)
/// } catch let error as RepositoryDiscoveryError {
///     switch error {
///     case .accessDenied(let url):
///         print("Cannot access: \(url.path)")
///     case .invalidRepository(let url):
///         print("Invalid repository at: \(url.path)")
///     case .verificationFailed(let url, let reason):
///         print("Verification failed at \(url.path): \(reason)")
///     case .discoveryFailed(let reason):
///         print("Discovery failed: \(reason)")
///     }
/// }
/// ```
///
/// ## Topics
/// ### Error Cases
/// - ``accessDenied(_:)``
/// - ``locationNotAccessible(_:)``
/// - ``invalidRepository(_:)``
/// - ``verificationFailed(_:_:)``
/// - ``discoveryFailed(_:)``
///
/// ### Error Information
/// - ``errorDescription``
/// - ``recoverySuggestion``
public enum RepositoryDiscoveryError: LocalizedError {
    /// Access to the specified location was denied
    case accessDenied(URL)

    /// The specified location is not accessible
    case locationNotAccessible(URL)

    /// Invalid repository structure found
    case invalidRepository(URL)

    /// Repository verification failed
    case verificationFailed(URL, String)

    /// General error during discovery
    case discoveryFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .accessDenied(url):
            "Access denied to location: \(url.path)"
        case let .locationNotAccessible(url):
            "Location not accessible: \(url.path)"
        case let .invalidRepository(url):
            "Invalid repository structure at: \(url.path)"
        case let .verificationFailed(url, reason):
            "Repository verification failed at \(url.path): \(reason)"
        case let .discoveryFailed(reason):
            "Repository discovery failed: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            "Please ensure you have appropriate permissions and try again."
        case .locationNotAccessible:
            "Please check if the location exists and is accessible."
        case .invalidRepository:
            "The location does not contain a valid Restic repository structure."
        case .verificationFailed:
            "Please ensure the repository is not corrupted and try again."
        case .discoveryFailed:
            "Please try the operation again. If the problem persists, check the logs for more details."
        }
    }
}
