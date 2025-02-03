# rBUM (Restic Backup Manager) Project Brief

## Project Overview
rBUM is a macOS application for managing Restic backups with a focus on user-friendly interface and robust security. The application is built using SwiftUI and follows modern Apple development practices.

## Core Architecture
- Protocol-based design for platform independence
- Core module containing platform-agnostic components
- Dependency injection for all external services
- Comprehensive error handling and logging

## Key Components

### 1. Core Module
- Platform-agnostic models and protocols
- Logging abstraction layer
- Error type definitions
- Service interfaces

### 2. Platform Implementation
- macOS-specific service implementations
- SwiftUI views and view models
- Security and sandbox compliance
- File system access management

### 3. Logging System
- Platform-agnostic LoggerProtocol
- Privacy-aware logging with multiple levels
- Category-based logger initialization
- Consistent error diagnostics
- British English conventions in user-facing messages

### 4. Security Features
- Sandbox compliance
- Security-scoped bookmarks
- Keychain integration
- Secure credential management
- Proper permission handling

## Development Status

### Completed
1. Core Module Architecture
   - Protocol-based design
   - Model definitions
   - Error handling structure

2. Logging System Migration
   - Platform-agnostic logging system
   - Privacy levels implementation
   - Category-based loggers
   - Consistent error logging

3. Security Implementation
   - Sandbox compliance
   - Security-scoped bookmarks
   - Keychain integration

### In Progress
1. UI Implementation
   - Repository management views
   - Backup configuration
   - Progress monitoring
   - Error handling UI

2. Testing
   - Unit tests for Core module
   - Integration tests
   - UI tests
   - Sandbox compliance tests

### Planned
1. Performance Optimisation
   - Backup operations
   - Large repository handling
   - Resource management

2. Additional Features
   - Backup scheduling
   - Advanced filtering
   - Statistics and reporting

## Development Guidelines

### Code Style
1. Swift
   - Swift 5.9.2 syntax
   - Explicit type annotations
   - Protocol-oriented design
   - Async/await for asynchronous operations

2. Architecture
   - MVVM pattern
   - Protocol-based abstractions
   - Dependency injection
   - Clear separation of concerns

3. Testing
   - Comprehensive unit tests
   - UI testing
   - Performance testing
   - Security testing

### Documentation
1. Code Documentation
   - Clear function documentation
   - Protocol requirements
   - Error conditions
   - Usage examples

2. User Documentation
   - Installation guide
   - User manual
   - Troubleshooting guide
   - Security best practices

## Logging and Privacy Guidelines

rBUM implements comprehensive logging while maintaining strict privacy controls to protect user data. This section outlines our logging patterns and privacy commitments.

### Privacy-First Logging

All logging in rBUM follows these privacy principles:

1. **Sensitive Data Protection**
   - File paths are always marked as `.private`
   - Credentials and tokens are never logged
   - Error details are sanitized to prevent data leaks
   - Debug information is private by default

2. **Public Information**
   - Progress indicators (e.g., backup progress)
   - Operation status (success/failure)
   - Non-sensitive error codes
   - General flow indicators

3. **Log Level Guidelines**
   - `debug`: Detailed information for troubleshooting (always private)
   - `info`: General operation progress (mixed privacy)
   - `error`: Issues requiring attention (sensitive details private)

### Implementation

```swift
// Example of proper privacy annotations
logger.debug("Processing file: \(path.path, privacy: .private)")
logger.info("Backup progress: \(progress, privacy: .public)%")
logger.error("Operation failed: \(error.localizedDescription, privacy: .private)")
```

### Service-Specific Guidelines

1. **BackupService**
   - Repository paths: `.private`
   - Backup progress: `.public`
   - File operations: `.private`

2. **SecurityService**
   - All security operations: `.private`
   - Permission status: `.public`
   - Error details: `.private`

3. **ResticService**
   - Command types: `.public`
   - Command arguments: `.private`
   - Operation results: `.public`

4. **BookmarkService**
   - All paths: `.private`
   - Bookmark data: `.private`
   - Operation status: `.public`

### Testing Requirements

1. **Privacy Verification**
   - Test cases must verify privacy annotations
   - Mock loggers must preserve privacy levels
   - No sensitive data in test outputs

2. **Log Format**
   ```swift
   // Standard log format
   [filename:line] message
   ```

3. **Test Cases**
   - Verify privacy levels are maintained
   - Check log message formatting
   - Validate sensitive data handling

### Compliance

This logging system ensures:
- Compliance with Apple's privacy guidelines
- Protection of user data in system logs
- Useful debugging capabilities
- Clear audit trail for operations
- Proper handling of security-sensitive information

## XPC Service Architecture

### Overview
rBUM uses an XPC service to securely execute the Restic command-line tool whilst maintaining sandbox compliance. This architecture provides enhanced security through process isolation and controlled resource access.

### Components

#### 1. ResticService (XPC Service)
- Dedicated process for executing Restic commands
- Sandboxed with minimal required permissions
- Handles command execution and output capture
- Manages process lifecycle and environment

```swift
@objc public protocol ResticServiceProtocol {
    func executeCommand(_ command: String, 
                       arguments: [String], 
                       environment: [String: String], 
                       workingDirectory: String, 
                       withReply reply: @escaping (Data?, Error?) -> Void)
}
```

#### 2. ResticCommandService (Main App)
- Manages XPC service connection
- Handles security-scoped resource access
- Provides high-level command interface
- Implements error handling and recovery

### Security Model

#### 1. Process Isolation
- XPC service runs in separate process
- Limited entitlements for command execution
- Controlled access to system resources
- Secure IPC through XPC protocol

#### 2. Resource Access
- Main app manages security-scoped bookmarks
- XPC service receives pre-validated paths
- Temporary resources cleaned up automatically
- Access tracking for all external resources

#### 3. Error Handling
- Connection failure recovery
- Command execution monitoring
- Resource cleanup on failures
- Proper error propagation

### Implementation Details

#### 1. XPC Service Configuration
```xml
<!-- ResticService.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
    <string>/usr/local/bin/restic</string>
</array>
```

#### 2. Command Execution Flow
1. Main app validates access to repository
2. XPC service executes Restic command
3. Output captured and returned to main app
4. Resources cleaned up automatically

#### 3. Error Recovery
1. XPC connection monitoring
2. Automatic reconnection on failure
3. Resource access verification
4. Command retry mechanisms

### Testing Requirements

#### 1. XPC Communication Tests
- Connection establishment
- Command execution
- Error handling
- Resource cleanup

#### 2. Integration Tests
- End-to-end command execution
- Resource access patterns
- Error recovery scenarios
- Performance impact

#### 3. Security Tests
- Sandbox compliance
- Resource isolation
- Permission handling
- Error conditions

### Deployment Considerations

#### 1. Code Signing
- Both app and XPC service must be signed
- Entitlements properly configured
- Security-scoped bookmark handling
- Resource access permissions

#### 2. Installation
- XPC service bundled with main app
- Proper bundle structure
- Resource copying
- Permission setup

#### 3. Updates
- Version synchronisation
- Compatibility checking
- Resource migration
- Error handling

### Troubleshooting Guide

#### 1. Connection Issues
- Check XPC service availability
- Verify entitlements
- Review system logs
- Check process status

#### 2. Permission Problems
- Verify sandbox configuration
- Check security-scoped bookmarks
- Review access patterns
- Check error logs

#### 3. Performance Issues
- Monitor resource usage
- Check command execution time
- Review connection status
- Analyze error patterns

### Best Practices

1. Resource Management
   - Use security-scoped bookmarks
   - Implement proper cleanup
   - Monitor resource usage
   - Handle timeouts appropriately

2. Error Handling
   - Implement connection recovery
   - Provide clear error messages
   - Log relevant information
   - Clean up resources

3. Security
   - Minimal permissions
   - Resource isolation
   - Secure communication
   - Proper authentication

4. Testing
   - Comprehensive test suite
   - Security validation
   - Performance monitoring
   - Error simulation

## Sandbox Compliance

### Overview
rBUM is fully sandboxed to ensure the security of user data and system resources. This section outlines our sandbox implementation, security measures, and compliance requirements.

### Sandbox Architecture

#### 1. Permission Management
- Security-scoped bookmarks for persistent file access
- Keychain-based permission storage
- Automatic permission recovery mechanisms
- User-friendly permission request UI

#### 2. Resource Access Control
- Strict access tracking for all external resources
- Proper start/stop access patterns
- Automatic resource cleanup
- Access duration monitoring

#### 3. Security Measures
- Sandbox violation detection
- System directory access prevention
- Temporary file management
- Secure environment configuration

### Implementation Details

#### Security-Scoped Bookmarks
```swift
// Request and store bookmark
let bookmark = try await securityService.createBookmark(for: url)
try permissionManager.persistBookmark(bookmark, for: url)

// Access resource
guard securityService.startAccessingWithMonitoring(url) else {
    throw SecurityError.accessDenied(url.path)
}
defer {
    securityService.stopAccessingWithMonitoring(url)
}
```

#### Working Directory Management
- Located at: `~/Library/Containers/dev.mpy.rBUM/Data/tmp`
- Automatic cleanup of files older than 24 hours
- Secure permissions (0o700)
- Process-specific subdirectories

#### Required Entitlements
```xml
<!-- App Sandbox -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- File Access -->
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>

<!-- Network Access -->
<key>com.apple.security.network.client</key>
<true/>
```

### Best Practices

1. Resource Access
   - Always use security-scoped bookmarks for persistent access
   - Implement proper start/stop access patterns
   - Monitor access duration
   - Clean up resources in `defer` blocks

2. File Operations
   - Use `FileManager` APIs for file operations
   - Respect sandbox container boundaries
   - Handle permission errors gracefully
   - Implement proper error recovery

3. Network Access
   - Use URLSession for network operations
   - Handle network errors appropriately
   - Respect network sandbox restrictions
   - Implement proper timeout handling

4. User Interface
   - Clear permission request dialogs
   - Proper error messaging
   - Progress feedback for long operations
   - Recovery options for permission failures

### Testing Requirements

1. Sandbox Compliance Tests
   - Security-scoped resource access
   - Bookmark creation and resolution
   - Permission persistence
   - Resource cleanup

2. Error Handling Tests
   - Permission denial scenarios
   - Resource access failures
   - Network restrictions
   - Recovery mechanisms

3. Performance Tests
   - Resource access overhead
   - Permission checking impact
   - Bookmark resolution speed
   - Cleanup efficiency

### Troubleshooting

1. Permission Issues
   - Check bookmark validity
   - Verify security-scoped resource access
   - Review system logs
   - Check entitlements

2. Access Violations
   - Monitor sandbox violations
   - Review access patterns
   - Check resource cleanup
   - Verify permission persistence

3. Recovery Steps
   - Re-request permissions
   - Clear invalid bookmarks
   - Reset sandbox state
   - Update entitlements

### Security Considerations

1. Data Protection
   - Secure storage of bookmarks
   - Protected temporary files
   - Proper permission handling
   - Access monitoring

2. Privacy
   - Minimal permission requests
   - Clear user consent
   - Proper data handling
   - Secure logging

3. Compliance
   - App Store requirements
   - macOS security guidelines
   - Privacy regulations
   - Security best practices

## Build and Deployment
- Xcode-based development
- Static analyzer integration
- Sandbox compliance checking
- Code signing and notarisation

## Project Timeline
- Phase 1: Core Architecture (Completed)
- Phase 2: Logging System Migration (Completed)
- Phase 3: UI Implementation (In Progress)
- Phase 4: Testing and Refinement (Planned)
- Phase 5: Performance Optimisation (Planned)
- Phase 6: Additional Features (Planned)
