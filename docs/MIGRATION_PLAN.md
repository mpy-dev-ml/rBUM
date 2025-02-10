# UmbraCore Migration Plan

## Overview
This document outlines the plan for migrating core components from rBUM to UmbraCore, which will serve as the foundation for three distinct applications:
- ResticBar (macOS menu bar app for developers)
- Rbx (VS Code extension for developers)
- Rbum (consumer GUI for Restic management)

## Phase 1: Core Framework Setup
### 1.1 Initial Structure
```
UmbraCore/
├── Sources/
│   ├── Core/
│   │   ├── Models/
│   │   ├── Protocols/
│   │   ├── Services/
│   │   ├── Errors/
│   │   └── Logging/
│   └── XPC/
│       ├── Protocols/
│       └── Services/
├── Tests/
│   ├── CoreTests/
│   └── XPCTests/
└── Documentation/
```

### 1.2 Components to Migrate
#### Core Components
- **Models**
  - Repository
  - RepositoryCredentials
  - ResticSnapshot
  - BackupConfiguration
  - ProcessResult

- **Protocols**
  - LoggerProtocol
  - FileManagerProtocol
  - SecurityServiceProtocol
  - NotificationProtocol
  - DateProviderProtocol

- **Services**
  - Security Services
    * KeychainService
    * CredentialsStorage
  - Storage Services
    * ConfigurationStorage
  - Process Services
    * ResticProcessService

- **Errors**
  - RepositoryError
  - CredentialsError
  - ProcessError
  - RepositoryDiscoveryError

#### XPC Components
- **Protocols**
  - XPCProtocol
  - ResticCommandProtocol

- **Services**
  - XPCService
  - ResticCommandService

## Phase 2: Migration Process
### 2.1 Core Framework Migration
1. Set up Xcode project structure
2. Implement core protocols
3. Migrate model definitions
4. Transfer error types
5. Implement service interfaces
6. Set up logging framework

### 2.2 XPC Service Migration
1. Set up XPC service structure
2. Migrate XPC protocols
3. Transfer command handling
4. Implement security measures
5. Set up sandboxing

### 2.3 Testing Infrastructure
1. Set up test targets
2. Migrate existing tests
3. Create new test cases
4. Implement mock objects
5. Set up CI/CD pipeline

## Phase 3: Documentation
### 3.1 Technical Documentation
1. API documentation
2. Architecture overview
3. Security considerations
4. Implementation guidelines

### 3.2 Integration Guides
1. ResticBar integration guide
2. Rbx integration guide
3. Future Rbum integration guide

## Phase 4: Quality Assurance
### 4.1 Code Quality
1. SwiftLint configuration
2. Static analysis setup
3. Code coverage requirements
4. Performance benchmarks

### 4.2 Security Review
1. Sandbox compliance
2. XPC security review
3. Credential handling audit
4. Permission model review

## Implementation Timeline

### Week 1 (Current Sprint)
- Core framework setup
- Essential protocols migration
- Basic model implementation
- Initial test framework

### Week 2
- XPC service migration
- Security implementation
- Integration tests
- Initial documentation

## Migration Guidelines

### Code Style
- Swift 5.9.2 compliance
- Explicit type annotations
- Comprehensive documentation
- British English in comments/docs
- American English in code

### Security Requirements
- Sandbox compliance
- XPC communication security
- Secure credential storage
- Permission handling

### Testing Requirements
- Unit test coverage > 80%
- Integration test suite
- Performance benchmarks
- Security test cases

## Dependencies
- swift-log
- Security.framework
- XPC.framework

## Repository Information
- UmbraCore: https://github.com/mpy-dev-ml/UmbraCore
- ResticBar: https://github.com/mpy-dev-ml/ResticBar
- Rbx: https://github.com/mpy-dev-ml/Rbx

## Next Steps

1. Create initial Xcode project structure
2. Set up core framework targets
3. Begin protocol migration
4. Set up CI/CD pipeline

## Notes
- All user-facing documentation uses British English spelling
- Code follows Swift standard library conventions (American English)
- Maintain strict sandboxing compliance throughout migration
- Ensure all security measures are maintained during transition
