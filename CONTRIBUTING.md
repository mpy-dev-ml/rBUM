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

### Framework Usage

We use a hybrid testing approach:

1. **Swift Testing Framework** (Primary for Unit Tests)
   - All new unit tests should use Swift Testing
   - Use `@Test` attribute with descriptive names
   - Implement tags for test organisation
   - Use `#expect` for assertions
   - Leverage parameterized testing where applicable

   Example:
   ```swift
   @Test("Repository creation with valid credentials", 
         .tags(.repository, .security))
   func testRepositoryCreation() async throws {
       // Given
       let credentials = RepositoryCredentials(...)
       
       // When
       let result = try await repositoryService.create(with: credentials)
       
       // Then
       #expect(result.isSuccess)
   }
   ```

2. **XCTest Framework** (UI and Performance Tests)
   - Use for UI automation tests
   - Use for performance measurements
   - Follow XCTest patterns for these specific cases

### Test Organisation

1. **Directory Structure**
   ```
   rBUM/Tests/
   ├── UnitTests/        # Swift Testing
   ├── UITests/          # XCTest
   └── PerformanceTests/ # XCTest
   ```

2. **Test Plans**
   - Use appropriate test plan for your changes:
     - `UnitTests.xctestplan` for Swift Testing tests
     - `UITests.xctestplan` for UI tests
     - `PerformanceTests.xctestplan` for performance tests

3. **Tags**
   Use appropriate tags for test organisation:
   - `.core` - Core functionality
   - `.security` - Security-related tests
   - `.storage` - Storage-related tests
   - `.ui` - UI-related tests
   - `.network` - Network-dependent tests
   - `.performance` - Performance-sensitive tests
   - `.integration` - Integration tests
   - `.unit` - Unit tests

### Test Writing Guidelines

1. **Naming Conventions**
   - Use British English in test names and descriptions
   - Follow the pattern: `test[Feature][Scenario][ExpectedResult]`
   - Make test names descriptive and specific

2. **Structure**
   - Use Given-When-Then pattern
   - Keep tests focused and atomic
   - Use appropriate mocks and test doubles
   - Handle async operations properly

3. **Coverage Requirements**
   - Models: 95% coverage
   - Services: 90% coverage
   - ViewModels: 85% coverage
   - UI Components: 75% coverage

4. **Performance Tests**
   - Include baseline measurements
   - Test with various data sizes
   - Document performance expectations
   - Use appropriate metrics for measurement

### Running Tests

1. **Local Development**
   - Run relevant test plan before submitting PR
   - Ensure all tests pass in both Debug and Release
   - Check code coverage requirements are met

2. **CI/CD Pipeline**
   - All tests must pass in CI
   - Coverage reports will be generated
   - Performance tests will be compared to baselines

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
