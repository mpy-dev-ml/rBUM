# Development Services

Development mock implementations of core services for testing and development purposes.

## Overview

Located in `Core/Sources/Services/Development`, these services provide controlled, in-memory implementations of core system services without requiring actual system access or security credentials. They are designed to facilitate rapid development and reliable testing.

## Available Services

### Security Service
`DevelopmentSecurityService` provides:
- Simulated security checks and validations
- Configurable access patterns for testing
- In-memory permission tracking
- Sandbox compliance verification

### Keychain Service
`DevelopmentKeychainService` offers:
- Secure in-memory credential storage
- Simulated encryption operations
- Configurable timeout scenarios
- Access control simulation

### Bookmark Service
`DevelopmentBookmarkService` implements:
- Security-scoped bookmark simulation
- In-memory bookmark storage and retrieval
- Configurable staleness scenarios
- Access tracking and validation

### XPC Service
`DevelopmentXPCService` provides:
- Simulated XPC communication
- Configurable response latency
- Error scenario simulation
- Resource cleanup tracking

## Implementation

### Service Configuration
Each service accepts a configuration object:
```swift
let config = DevelopmentSecurityService.Configuration(
    shouldSimulatePermissionFailures: false,
    shouldSimulateBookmarkFailures: false,
    artificialDelay: 0.5
)
```

### Service Factory Integration
Services are automatically created via ServiceFactory:
```swift
let securityService = ServiceFactory.createSecurityService(
    logger: logger,
    configuration: config
)

let keychainService = ServiceFactory.createKeychainService(
    logger: logger,
    configuration: config
)
```

### Thread Safety
- All services use concurrent dispatch queues
- Resource access is properly synchronized
- Operations are atomic where necessary
- Deadlock prevention measures

## Best Practices

### Configuration Management
1. Start with default configurations
2. Add specific failure scenarios as needed
3. Use artificial delays to test async behaviour
4. Document custom configurations

### Logging Guidelines
1. Use appropriate log levels:
   - `.debug` for operation details
   - `.info` for state changes
   - `.warning` for recoverable issues
   - `.error` for failures
2. Include relevant context in logs
3. Use British English in messages

### Error Handling
1. Test both success and failure paths
2. Verify error messages are descriptive
3. Ensure proper error propagation
4. Test recovery scenarios

### Testing Strategies
1. Unit Tests:
   - Test each service in isolation
   - Verify all configuration options
   - Test edge cases
   - Validate error conditions

2. Integration Tests:
   - Test service interactions
   - Verify proper cleanup
   - Test concurrent access
   - Validate state transitions

## Benefits

- Rapid Development:
  - No security credentials needed
  - Quick iteration cycles
  - Immediate feedback

- Reliable Testing:
  - Controlled environment
  - Reproducible scenarios
  - Consistent behaviour

- Easy Debugging:
  - Comprehensive logging
  - Clear error messages
  - State inspection

First created: 6 February 2025
Last updated: 7 February 2025
