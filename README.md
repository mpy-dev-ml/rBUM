# rBUM (Restic Backup Manager)

A macOS application for managing restic backups with a clean, modular architecture.

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

## Development

### Requirements
- Xcode 15.0+
- Swift 5.9.2
- macOS 14.0+

### Building
1. Open `rBUM.xcodeproj` in Xcode
2. Build the project (⌘B)
3. Run the app (⌘R)

## Contributing
Please see CONTRIBUTING.md for guidelines.

## License
[Your license here]
