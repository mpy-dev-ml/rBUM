# ``Core``

The Core framework provides the foundational services and protocols for the rBUM (Restic Backup Manager) application.

## Overview

Core provides essential functionality for managing restic backups, including:
- Secure credential management through Keychain
- Sandbox-compliant file operations
- XPC service communication
- Error handling and logging

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:Security>

### Services
- ``RepositoryServiceProtocol``
- ``KeychainCredentialsManagerProtocol``
- ``SecurityServiceProtocol``
- ``BookmarkServiceProtocol``

### Models
- ``Repository``
- ``Snapshot``
- ``BackupProgress``

### Error Handling
- ``ServiceError``
- ``SecurityError``
- ``KeychainError``
- ``SandboxError``

### XPC Communication
- ``ResticXPCServiceProtocol``
- ``XPCConnection``

First created: 6 February 2025
Last updated: 6 February 2025
