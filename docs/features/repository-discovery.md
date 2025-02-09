# Repository Discovery Feature

## Overview
The Repository Discovery feature allows users to scan their drives for existing Restic repositories, add them to rBUM for management, and index them for searching. This document outlines the implementation details, architecture, and usage guidelines.

## Architecture

### Core Components

1. **Models**
   - `DiscoveredRepository`: Represents a discovered Restic repository
   - `RepositoryMetadata`: Contains metadata about a repository
   - `RepositoryDiscoveryError`: Error types specific to discovery operations

2. **Protocols**
   - `RepositoryDiscoveryProtocol`: Core interface for discovery operations
   - `RepositoryDiscoveryXPCProtocol`: XPC interface for filesystem operations

3. **Services**
   - `RepositoryDiscoveryService`: Main service implementation
   - ResticService extension for XPC operations

4. **View Model**
   - `RepositoryDiscoveryViewModel`: Manages UI state and business logic

5. **Views**
   - `RepositoryDiscoveryView`: SwiftUI interface for user interaction

## Implementation Details

### Security Considerations

1. **Sandbox Compliance**
   - Uses security-scoped bookmarks for persistent access
   - Proper access request/release cycle
   - Secure storage of access tokens

2. **XPC Communication**
   - Privileged operations performed in XPC service
   - Secure parameter passing
   - Error handling across process boundaries

### Repository Discovery Process

1. **Scanning Phase**
   ```swift
   func scanLocation(_ url: URL, recursive: Bool) async throws -> [DiscoveredRepository]
   ```
   - Validates directory access
   - Optionally scans subdirectories
   - Identifies potential repositories
   - Collects initial metadata

2. **Verification Phase**
   ```swift
   func verifyRepository(_ repository: DiscoveredRepository) async throws -> Bool
   ```
   - Validates repository structure
   - Checks config file integrity
   - Verifies data directory

3. **Indexing Phase**
   ```swift
   func indexRepository(_ repository: DiscoveredRepository) async throws
   ```
   - Processes repository contents
   - Builds search index
   - Prepares for integration

## Usage Guidelines

### Adding a Repository

1. Select a directory to scan:
   ```swift
   viewModel.startScan(at: directoryURL, recursive: true)
   ```

2. Review discovered repositories in the UI

3. Add selected repository:
   ```swift
   try await viewModel.addRepository(selectedRepository)
   ```

### Error Handling

The feature handles several error cases:
- Access denied
- Invalid repository structure
- Verification failures
- Indexing errors

Example error handling:
```swift
do {
    try await viewModel.addRepository(repository)
} catch let error as RepositoryDiscoveryError {
    // Handle specific error cases
} catch {
    // Handle unexpected errors
}
```

## Testing

### Unit Tests
- `RepositoryDiscoveryViewModelTests`: Tests view model behaviour
- `RepositoryDiscoveryTests`: Tests XPC service implementation

### Integration Tests
- `RepositoryDiscoveryIntegrationTests`: Tests full workflow

## Performance Considerations

1. **Large Directory Scans**
   - Implements cancellation support
   - Progress updates
   - Batch processing

2. **Resource Management**
   - Proper cleanup of file handles
   - Memory-efficient metadata collection
   - Background processing for indexing

## User Interface

The interface provides:
- Directory selection
- Progress indication
- Repository list with metadata
- Error feedback
- Context menu actions

## Future Enhancements

1. **Planned Improvements**
   - Advanced filtering options
   - Batch repository operations
   - Network repository discovery
   - Improved metadata collection

2. **Integration Opportunities**
   - Backup scheduling
   - Repository health monitoring
   - Space usage analytics

## Troubleshooting

Common issues and solutions:

1. **Access Denied**
   - Verify directory permissions
   - Check sandbox entitlements
   - Validate security-scoped bookmarks

2. **Invalid Repositories**
   - Verify repository structure
   - Check config file integrity
   - Validate data directory contents

3. **Performance Issues**
   - Limit recursive scan depth
   - Use appropriate batch sizes
   - Monitor system resources

## API Reference

### Core Protocol
```swift
public protocol RepositoryDiscoveryProtocol {
    func scanLocation(_ url: URL, recursive: Bool) async throws -> [DiscoveredRepository]
    func verifyRepository(_ repository: DiscoveredRepository) async throws -> Bool
    func indexRepository(_ repository: DiscoveredRepository) async throws
    func cancelDiscovery()
}
```

### XPC Protocol
```swift
@objc public protocol RepositoryDiscoveryXPCProtocol {
    func scanLocation(_ url: URL, recursive: Bool, reply: @escaping ([URL]?, Error?) -> Void)
    func verifyRepository(at url: URL, reply: @escaping (Bool, Error?) -> Void)
    func getRepositoryMetadata(at url: URL, reply: @escaping ([String: Any]?, Error?) -> Void)
    func indexRepository(at url: URL, reply: @escaping (Error?) -> Void)
    func cancelOperations()
}
```

## Best Practices

1. **Error Handling**
   - Always handle specific error cases
   - Provide clear user feedback
   - Implement proper recovery paths

2. **Resource Management**
   - Release file handles promptly
   - Clean up temporary resources
   - Monitor memory usage

3. **User Experience**
   - Show clear progress indicators
   - Provide cancellation options
   - Display helpful error messages

4. **Testing**
   - Maintain high test coverage
   - Use appropriate mocks
   - Test edge cases
