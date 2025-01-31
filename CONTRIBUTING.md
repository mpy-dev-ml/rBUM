# Contributing to rBUM

Thank you for your interest in contributing to rBUM! This document provides guidelines and information for contributors.

## Restic Compatibility

rBUM is a GUI wrapper for [Restic](https://restic.net/), and maintaining compatibility with Restic is our highest priority. When contributing, please ensure:

1. All backup operations are performed through Restic's command-line interface
2. No modifications are made to Restic's core functionality
3. Restic's security model is strictly respected
4. All Restic features remain accessible
5. Changes accommodate Restic's versioning and updates

For Restic-specific questions or issues, please refer to:
- [Restic Documentation](https://restic.readthedocs.io/)
- [Restic GitHub Issues](https://github.com/restic/restic/issues)
- [Restic Forum](https://forum.restic.net/)

## Development Environment

- Xcode 16.0 or later
- Swift 5.9.2
- macOS Ventura (13.0) or later
- Restic installed locally (via Homebrew recommended)

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
- Maintain consistent behaviour across views

### Storage and Security Guidelines

- Use the established storage services for data persistence
- Never store sensitive data outside of Keychain
- Follow atomic operation patterns for file writes
- Implement proper error handling and recovery
- Use the logging system with appropriate privacy controls
- Test storage operations thoroughly
- Validate configuration changes carefully
- Follow established patterns for:
  - Repository metadata storage
  - Credentials management
  - Configuration handling
  - Error handling and logging

### Documentation

- Use clear and concise comments
- Document public APIs using Swift's documentation comments
- Include usage examples for complex functionality
- Keep README and other documentation up to date
- Clearly indicate which features are provided by Restic vs. rBUM
- Use British English in all user-facing text

## Testing Guidelines

### Test Infrastructure

rBUM uses a bimodal testing strategy combining Swift Testing Framework and XCTest:

1. **Swift Testing Framework**
   - Used for unit tests (models, services, viewmodels)
   - Provides better async/await support
   - Enables tagged test organization
   - Uses TestContext pattern for dependency management
   - More readable test assertions with #expect

2. **XCTest**
   - Used for UI tests
   - Used for performance tests
   - Leverages Xcode's native testing tools

### Test Organization

- Tests are organized in separate test plans:
  - `rBUM.xctestplan`: Main test plan
  - `UnitTests.xctestplan`: Swift Testing-based unit tests
  - `UITests.xctestplan`: XCTest-based UI tests
  - `PerformanceTests.xctestplan`: XCTest-based performance tests

### Writing Tests

1. **Unit Tests**
   - Use Swift Testing Framework
   - Create a TestContext for dependency management
   - Use descriptive test names with @Test annotation
   - Add appropriate tags for test organization
   - Use #expect for assertions
   - Follow the Given-When-Then pattern

2. **UI Tests**
   - Use XCTest
   - Focus on user interaction flows
   - Test SwiftUI view hierarchy
   - Verify accessibility features

3. **Performance Tests**
   - Use XCTest
   - Set appropriate baselines
   - Test critical operations
   - Monitor memory and CPU usage

### Test Coverage

- Maintain high test coverage for critical paths
- Use Xcode's coverage reporting
- Focus on meaningful tests over coverage percentage
- Document untested edge cases

### Running Tests

1. **In Xcode**
   - Use Product > Test (⌘U)
   - Use Test navigator for specific tests
   - Check coverage in Report navigator

2. **Continuous Integration**
   - All tests must pass before merging
   - Coverage reports are generated
   - Performance tests are tracked

### Test Maintenance

- Keep tests up to date with implementation
- Regularly review and update test plans
- Monitor and update performance baselines
- Clean up obsolete tests

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

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Update the README if needed
5. Request review from maintainers
6. Describe changes and their impact on Restic integration
7. Document any new dependencies or requirements
8. Explain security implications, if any
9. Include relevant test results
10. Update documentation as needed

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
