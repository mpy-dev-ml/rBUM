# rBUM (Restic Backup Manager)

A modern, native macOS graphical user interface for [Restic](https://restic.net/), the fast, secure, and efficient backup programme. rBUM is designed to complement Restic by providing a native macOS interface whilst maintaining all of Restic's powerful features and security guarantees.

## Overview

rBUM provides an intuitive interface for managing Restic backups on macOS, focusing on simplicity and security. It leverages native macOS features including Passkeys for secure credential management.

## About Restic

Restic is an open-source backup programme developed by Alexander Neumann and the Restic team. It provides:
- Fast and secure backup solutions
- Support for multiple storage backends
- Encryption and deduplication
- Efficient snapshot management

rBUM is a GUI wrapper for Restic and is not affiliated with or endorsed by the Restic project. For more information about Restic, visit:
- [Restic Website](https://restic.net/)
- [Restic Documentation](https://restic.readthedocs.io/)
- [Restic GitHub Repository](https://github.com/restic/restic)

## Features

rBUM enhances Restic with:
- Native macOS interface built with SwiftUI
- Visual management of Restic repositories
- Snapshot creation and management
- Automated backup scheduling
- Repository discovery
- Secure credential management using macOS Passkeys
- Integrated Restic documentation and help
  - Command reference
  - Context-sensitive help
  - Quick reference guides
  - Offline documentation support

All backup operations are performed by Restic itself, ensuring full compatibility and security.

## Requirements

- macOS Sonoma (14.0) or later
- Xcode 16.0
- Swift 5.9.2
- Restic installed on your system (can be installed via `brew install restic`)

## Project Structure

```
rBUM/
├── rBUM/
│   ├── rBUMApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   ├── Repository.swift
│   │   ├── Snapshot.swift
│   │   └── BackupJob.swift
│   ├── Views/
│   │   ├── RepositoryListView.swift
│   │   ├── SnapshotListView.swift
│   │   ├── BackupView.swift
│   │   ├── RestoreView.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/
│   │   ├── RepositoryViewModel.swift
│   │   ├── SnapshotViewModel.swift
│   │   ├── BackupViewModel.swift
│   │   └── RestoreViewModel.swift
│   ├── Services/
│   │   ├── ResticCommandService.swift
│   │   ├── SchedulerService.swift
│   │   ├── DriveScanner.swift
│   │   └── Security/
│   ├── Utilities/
│   │   ├── ShellExecutor.swift
│   │   ├── Constants.swift
│   │   └── Extensions/
│   ├── Configuration/
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
├── rBUMTests/
└── rBUMUITests/
```

## Installation

1. Clone the repository
2. Open the project in Xcode 16.0 or later
3. Build and run the project

## Development

This project follows the MVVM (Model-View-ViewModel) architecture pattern and uses SwiftUI for the user interface.

For detailed development guidelines, please refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## Security

rBUM takes security seriously:
- Uses macOS Passkeys for secure credential storage
- Never stores Restic passwords in plaintext
- Leverages macOS Keychain for sensitive data

## Licence and Attribution

rBUM is licenced under the [MIT Licence](LICENSE). This project is independent of and not affiliated with the Restic project. Restic is licenced under BSD 2-Clause "Simplified" Licence and is copyright 2014-2023 Alexander Neumann and contributors.

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
