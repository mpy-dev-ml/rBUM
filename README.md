# rBUM (Restic Backup Manager)

![CI](https://github.com/mpy-dev-ml/rBUM/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/mpy-dev-ml/rBUM/branch/main/graph/badge.svg)](https://codecov.io/gh/mpy-dev-ml/rBUM)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A macOS application for managing restic backups with a clean, modular architecture.

## Project Structure

```
rBUM/
├── Core/                           # Core framework
│   ├── Core.docc/                 # Documentation catalog
│   ├── Sources/
│   │   ├── Errors/               # Error type definitions
│   │   │   ├── KeychainError.swift
│   │   │   ├── SandboxError.swift
│   │   │   ├── SecurityError.swift
│   │   │   └── ServiceError.swift
│   │   ├── Logging/             # Logging infrastructure
│   │   ├── Models/              # Core data models
│   │   ├── Protocols/           # Core protocols
│   │   │   ├── KeychainServiceProtocol.swift
│   │   │   ├── SecurityServiceProtocol.swift
│   │   │   └── ResticXPCServiceProtocol.swift
│   │   └── Services/            # Core services
│   │       ├── KeychainService.swift
│   │       ├── SecurityService.swift
│   │       ├── ResticXPCService.swift
│   │       └── Mock/            # Mock services
│   │           └── DummyXPCService.swift
│   └── Tests/                    # Core framework tests
│       ├── Mocks/               # Test mocks
│       ├── SandboxTests/        # Sandbox compliance tests
│       └── XPCTests/            # XPC service tests
├── CoreTests/                     # Additional core tests
│   ├── Mocks/                   # Mock implementations
│   ├── Models/                  # Model tests
│   ├── Protocols/               # Protocol tests
│   ├── Services/                # Service tests
│   └── XPCTests/               # XPC integration tests
├── rBUM/                         # Main application
│   ├── Services/
│   │   ├── Security/           # Security services
│   │   │   └── KeychainCredentialsManager.swift
│   │   └── Storage/            # Storage services
│   ├── ViewModels/              # View models
│   └── Views/                   # SwiftUI views
└── rBUMTests/                    # Main app tests
    └── Services/                # Service tests
```

## Architecture

### Security Architecture

The project implements a robust security architecture with the following components:

1. **KeychainCredentialsManager**
   - Manages secure storage of repository credentials
   - Uses KeychainService for sandbox-compliant operations
   - Handles XPC service integration for secure access

2. **KeychainService**
   - Implements secure keychain operations
   - Manages access groups for XPC sharing
   - Ensures sandbox compliance

3. **SecurityService**
   - Handles security-scoped bookmarks
   - Manages secure operations through XPC
   - Validates service access and permissions

4. **ResticXPCService**
   - Executes privileged operations
   - Manages secure inter-process communication
   - Handles process lifecycle and permissions

The security architecture ensures:
- Proper sandbox compliance
- Secure credential management
- Clear separation of concerns
- Protocol-oriented design
- Testability through mocks

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
First created: 6 February 2025
Last updated: 6 February 2025


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
