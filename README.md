# rBUM (Restic Backup Manager)

A modern, native macOS graphical user interface for Restic backup management, built with SwiftUI.

## Overview

rBUM provides an intuitive interface for managing Restic backups on macOS, focusing on simplicity and security. It leverages native macOS features including Passkeys for secure credential management.

## Features

- Create and manage Restic repositories
- Create and manage snapshots
- Schedule automated backups
- Scan drives for existing Restic repositories
- Secure password management using macOS Passkeys
- Native macOS interface built with SwiftUI

## Requirements

- macOS Sonoma (14.0) or later
- Xcode 16.0
- Swift 5.9.2
- Restic installed on your system

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

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.
