# Contributing to rBUM

Thank you for your interest in contributing to rBUM! This document provides guidelines and information for contributors.

## Development Environment

- Xcode 16.0 or later
- Swift 5.9.2
- macOS Ventura (13.0) or later
- Restic installed locally

## Code Style Guidelines

### Swift Style Guide

- Use Swift 5.9.2 features and syntax
- Follow Swift's official API Design Guidelines
- Use explicit type annotations when needed for clarity
- Prefer `let` over `var` when possible
- Use meaningful and descriptive names for variables, functions, and types

### SwiftUI Best Practices

- Keep views small and focused
- Use appropriate view modifiers
- Extract reusable components
- Follow MVVM architecture patterns

### Documentation

- Use clear and concise comments
- Document public APIs using Swift's documentation comments
- Include usage examples for complex functionality
- Keep README and other documentation up to date

## Git Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write or update tests
5. Submit a pull request

### Commit Messages

- Use clear and descriptive commit messages
- Start with a verb in the present tense
- Keep the first line under 72 characters
- Reference issue numbers when applicable

Example:
```
Add repository scanning functionality

- Implement drive scanning service
- Add UI for repository discovery
- Update documentation
```

## Testing

- Write unit tests for new functionality
- Ensure all tests pass before submitting PR
- Use XCTest framework
- Include UI tests for new views

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Update the README if needed
5. Request review from maintainers

## Code Review

- All code changes require review
- Address review comments promptly
- Keep discussions focused and professional
- Be open to feedback and suggestions

## Security Considerations

- Never commit sensitive information
- Use Passkeys and Keychain appropriately
- Follow macOS security best practices
- Report security issues privately to maintainers

## Questions?

If you have questions about contributing, please open an issue for discussion.
