# Getting Started with Core

Learn how to integrate and use the Core framework in your rBUM application.

## Overview

The Core framework provides essential services and protocols for managing restic backups in a sandboxed macOS environment. This guide will help you get started with using the framework's key features.

## First Steps

### Setting Up Services

```swift
import Core

// Initialize the services
let keychainService = KeychainService()
let securityService = SecurityService()
let bookmarkService = BookmarkService()

// Create a repository service
let repositoryService = RepositoryService(
    credentials: keychainService,
    security: securityService,
    bookmarks: bookmarkService
)
```

### Managing Repositories

```swift
// Create a new repository
let repository = try await repositoryService.create(
    at: url,
    password: "your-password"
)

// List snapshots
let snapshots = try await repositoryService.listSnapshots(
    for: repository
)
```

## Topics

### Essentials
- ``RepositoryServiceProtocol``
- ``Repository``
- ``Snapshot``

### Security
- ``KeychainCredentialsManagerProtocol``
- ``SecurityServiceProtocol``
- ``BookmarkServiceProtocol``

### Error Handling
- ``ServiceError``
- ``SecurityError``