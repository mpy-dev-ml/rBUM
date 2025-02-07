# ``Core``

The Core framework provides the foundational services and protocols for the rBUM (Restic Backup Manager) application.

## Overview

Core provides essential functionality for managing Restic backups, including:
- Secure credential management through Keychain
- Sandbox-compliant file operations
- XPC service communication for secure command execution
- Comprehensive error handling and logging
- Security-scoped bookmark management

## Architecture

The framework is organized into several key components:

### Services Layer
- Repository management and operations
- Secure credential storage and retrieval
- Sandbox-compliant file system access
- XPC service communication

### Security Layer
- Keychain integration for secure storage
- Security-scoped bookmark handling
- Sandbox compliance enforcement
- Access control and validation

### Model Layer
- Repository configuration and state
- Snapshot management and tracking
- Backup progress monitoring
- Error representation and handling

## Topics

### Getting Started
- <doc:GettingStarted>
- <doc:Security>
- <doc:Architecture>

### Core Services
- ``RepositoryServiceProtocol``
- ``KeychainCredentialsManagerProtocol``
- ``SecurityServiceProtocol``
- ``BookmarkServiceProtocol``

### Data Models
- ``Repository``
- ``Snapshot``
- ``BackupProgress``
- ``RepositoryCredentials``

### Error Handling
- ``ServiceError``
- ``SecurityError``
- ``KeychainError``
- ``SandboxError``

### XPC Communication
- ``ResticXPCServiceProtocol``
- ``XPCConnection``
- ``XPCError``

### Development Support
- ``DevelopmentServices``
- ``TestingUtilities``

First created: 6 February 2025
Last updated: 7 February 2025
