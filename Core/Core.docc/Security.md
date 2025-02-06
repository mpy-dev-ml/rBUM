# Security in Core

Learn about the security features and best practices in the Core framework.

## Overview

The Core framework implements several security measures to ensure safe handling of:
- Repository passwords
- Security-scoped bookmarks
- Sandbox compliance
- XPC service communication

## Topics

### Credential Management

The ``KeychainCredentialsManagerProtocol`` provides secure storage for repository passwords:

```swift
let credentials = KeychainService()

// Store credentials
try await credentials.store(
    password: "secret",
    for: repositoryId
)

// Retrieve credentials
let password = try await credentials.retrieve(
    for: repositoryId
)
```

### Sandbox Compliance

The ``SecurityServiceProtocol`` handles sandbox-compliant file access:

```swift
let security = SecurityService()

// Request access
let granted = try await security.requestAccess(to: url)

// Persist access
let bookmark = try security.persistAccess(to: url)
```

### XPC Communication

The ``ResticXPCServiceProtocol`` ensures secure command execution:

```swift
let service = ResticXPCService()

// Execute command
let result = try await service.execute(
    command: "snapshots",
    for: repository
)
```

## Topics

### Essential Services
- ``KeychainCredentialsManagerProtocol``
- ``SecurityServiceProtocol``
- ``ResticXPCServiceProtocol``

### Error Types
- ``SecurityError``
- ``KeychainError``
- ``SandboxError``