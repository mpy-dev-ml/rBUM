# rBUM (Restic Backup Manager)

A macOS application for managing restic backups with a clean, modular architecture.

## Project Structure

### Core Components
- `/Core/`: Core functionality and protocols
  - Protocols/: Core protocol definitions
  - Models/: Data models and types
  - Services/: Core services implementation
  - Platform/: Platform-specific abstractions

### Service Layer
- `/ResticService/`: XPC service for Restic operations
  - Inherits from Core.BaseService
  - Implements ResticXPCProtocol
  - Secure command execution with timeout handling
  - Process lifecycle management
  - Security validation pipeline:
    * Client code signing verification
    * Audit session validation
    * Security-scoped bookmark handling
  - Comprehensive error handling and logging

### Main Application
- `/rBUM/`: Main application source
  - Models/: Application-specific models
  - ViewModels/: SwiftUI view models
  - Views/: SwiftUI view components
  - Services/: Application services
  - Configuration/: App configuration
  - Utilities/: Helper utilities

### Testing
- `/CoreTests/`: Core module tests
- `/rBUMTests/`: Main app unit tests
  - Models/: Model tests
  - Services/: Service layer tests
  - ViewModels/: ViewModel tests
  - TestData/: Mock data
  - Utilities/: Test utilities
- `/rBUMUITests/`: UI automation tests

### Project Configuration
- `rBUM.xcodeproj/`: Xcode project configuration
- `rBUM.entitlements`: App sandbox and capabilities
- `.gitignore`: Git ignore patterns

### Support
- `/Scripts/`: Development and maintenance scripts

## Architecture

The project follows a clean, modular architecture:

### Core Module
- Platform-agnostic interfaces and models
- Core business logic
- Protocol-based design for flexibility

### Platform Module
- macOS-specific implementations
- System framework integrations
- Sandbox-compliant services

### Features
- Secure credential management
- Backup scheduling and monitoring
- Repository management
- Snapshot handling
- Secure XPC communication:
  * Version-controlled interface
  * Security validation
  * Resource access control
  * Timeout handling
  * Error propagation

## Development

### Requirements
- Xcode 15.0+
- Swift 5.9.2
- macOS 14.0+

### Building
1. Open `rBUM.xcodeproj` in Xcode
2. Build the project (⌘B)
3. Run the app (⌘R)

### XPC Service Development
1. The XPC service is embedded in the main application
2. Service requires Core.framework dependency
3. Testing through `CoreTests` XPC test suite
4. Security considerations:
   - Proper entitlements required
   - Sandbox compliance
   - Security-scoped bookmarks
   - Audit session validation

## Contributing
Please see CONTRIBUTING.md for guidelines.

## License
[Your license here]
