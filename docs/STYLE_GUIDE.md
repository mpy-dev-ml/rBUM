# rBUM Swift Style Guide

This document outlines the Swift coding standards and style guidelines for the rBUM project. These guidelines ensure consistency across the codebase and align with both Apple's Swift API Design Guidelines and British English conventions for user-facing elements.

## Table of Contents
- [File Organisation](#file-organisation)
- [Naming Conventions](#naming-conventions)
- [Documentation and Comments](#documentation-and-comments)
- [Code Organisation](#code-organisation)
- [Access Control](#access-control)
- [Type Safety](#type-safety)
- [Error Handling](#error-handling)
- [SwiftUI Specific Guidelines](#swiftui-specific-guidelines)
- [Testing](#testing)

## File Organisation

### General Rules
- One type per file
- Filename must match the type name (e.g., `BackupManager.swift`)
- Use extensions to organise code within files
- Group related files in appropriate directories

### Directory Structure
```
rBUM/
├── Sources/
│   ├── Controllers/
│   ├── Models/
│   ├── Views/
│   └── Utilities/
├── Tests/
└── Resources/
```

## Naming Conventions

### Types (Classes, Structs, Enums)
- Use UpperCamelCase
- Names should be clear and unambiguous
- Avoid abbreviations

```swift
// Good
class BackupController
struct RepositoryConfiguration
enum BackupState

// Bad
class BkpCtrl
struct RepoCfg
enum BkpSt
```

### Protocols
- Use UpperCamelCase
- Name protocols as nouns if they describe what something is
- Use -able, -ible, or -ing suffix for protocols that describe capabilities

```swift
protocol Repository
protocol BackupConfigurable
protocol RepositoryMonitoring
```

### Variables and Properties
- Use lowerCamelCase
- Be clear and concise
- Boolean properties should read as assertions

```swift
var backupLocation: URL
var isBackupInProgress: Bool
var hasValidCredentials: Bool

// Bad
var backup_location: URL
var flag: Bool
```

### Functions and Methods
- Use lowerCamelCase
- Use verb phrases to name actions
- Be clear about parameter roles

```swift
// Good
func initiateBackup(for path: String)
func validateRepository(at location: URL) throws
func restoreFiles(from snapshot: Snapshot, to destination: URL)

// Bad
func backup(_ str: String)
func validate(_ url: URL)
```

### Enums
- Cases use lowerCamelCase

```swift
enum BackupFrequency {
    case hourly
    case daily
    case weekly
    case monthly
}
```

## Documentation and Comments

### General Rules
- Use British English for all user-facing documentation
- Document all public interfaces
- Use Swift's markup syntax

### Documentation Style
```swift
/// The primary controller for managing backup operations.
/// Handles scheduling, monitoring, and error reporting.
///
/// - Important: Ensure proper initialisation before use.
///
/// - Parameter configuration: The configuration to use for backups.
/// - Throws: `BackupError.invalidConfiguration` if the configuration is invalid.
class BackupController {
    // Implementation
}
```

## Code Organisation

### Type Definition Order
1. Type declaration
2. Properties
3. Initialisers
4. Public methods
5. Private methods
6. Extension methods

```swift
class RepositoryManager {
    // Properties
    private let configuration: Configuration
    
    // Initialisers
    init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    // Public methods
    func initialiseRepository() throws {
        // Implementation
    }
    
    // Private methods
    private func validateConfiguration() -> Bool {
        // Implementation
    }
}
```

## Access Control

### Guidelines
- Be explicit about access control
- Default to `private` unless needed otherwise
- Use `internal` when type/property should be accessible within the module
- Reserve `public` for API boundaries

```swift
public class RepositoryManager {
    private let configuration: Configuration
    internal var state: RepositoryState
    
    public func initialiseRepository() throws {
        // Implementation
    }
}
```

## Type Safety

### Guidelines
- Be explicit with types when it improves clarity
- Use type inference when the type is obvious
- Always use strong types; avoid implicitly unwrapped optionals
- Use `guard` for early returns

```swift
// Good
let repository: Repository = Repository(path: path)
guard let configuration = loadConfiguration() else { return }

// Bad
let repo = Repository(path: path)
if let config = loadConfiguration() {
    // Nested code
}
```

## Error Handling

### Error Types
- Use meaningful custom error types
- Provide descriptive error messages
- Handle all error cases appropriately

```swift
enum RepositoryError: Error {
    case initialisationFailed(String)
    case invalidConfiguration(String)
    case insufficientPermissions(String)
    
    var localizedDescription: String {
        switch self {
        case .initialisationFailed(let reason):
            return "Repository initialisation failed: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .insufficientPermissions(let reason):
            return "Insufficient permissions: \(reason)"
        }
    }
}
```

## SwiftUI Specific Guidelines

### View Structure
- Use meaningful names for views
- Keep view components small and focused
- Use view modifiers in a logical order
- Group related modifiers together

```swift
struct BackupStatusView: View {
    var body: some View {
        VStack {
            StatusIndicator()
                .frame(width: 44, height: 44)
                .accessibility(label: Text("Backup Status"))
                .padding()
        }
    }
}
```

### View Modifiers
- Chain modifiers in a logical order:
  1. Layout (frame, padding)
  2. Appearance (foregroundColor, background)
  3. Interaction (onTapGesture)
  4. Accessibility

## Testing

### Test Structure
- Test files should mirror the structure of the code they test
- Use clear, descriptive test names
- Follow the Given-When-Then pattern
- Name test classes with a `Tests` suffix

```swift
class RepositoryManagerTests: XCTestCase {
    func testInitialisation_WithValidConfiguration_Succeeds() {
        // Given
        let configuration = validTestConfiguration()
        
        // When
        let manager = RepositoryManager(configuration: configuration)
        
        // Then
        XCTAssertNotNil(manager)
    }
}
```

### Test Naming
- Use descriptive names that explain the test scenario
- Format: test_[UnitOfWork]_[Scenario]_[ExpectedBehaviour]

```swift
func testBackup_WithLargeFiles_CompletesSuccessfully()
func testRestore_WithInvalidSnapshot_ThrowsError()
```

---

This style guide is a living document and will be updated as new patterns and best practices emerge. All contributors to the rBUM project should follow these guidelines to maintain consistency across the codebase.
