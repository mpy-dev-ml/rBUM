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
