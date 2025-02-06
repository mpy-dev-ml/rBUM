# Development Services

Development mock implementations of core services for testing and development purposes.

## Overview

Located in `Core/Sources/Services/Development`, these services provide controlled, in-memory implementations of core system services without requiring actual system access or security credentials.

## Services

1. `DevelopmentSecurityService`
   - Simulated security checks
   - Configurable access patterns
   - In-memory permission tracking

2. `DevelopmentKeychainService`
   - In-memory credential storage
   - Simulated encryption
   - Configurable timeout scenarios

3. `DevelopmentBookmarkService`
   - Simulated bookmark creation/resolution
   - In-memory bookmark storage
   - Configurable staleness scenarios

4. `DevelopmentXPCService`
   - Simulated XPC responses
   - Configurable latency
   - Error scenario simulation

## Usage

1. Development Environment
   - Services automatically used in DEBUG builds via ServiceFactory
   - All operations logged for debugging
   - No actual security credentials needed

2. Configuration
   Each service has a Configuration struct with options like:
   ```swift
   let config = DevelopmentSecurityService.Configuration(
       shouldSimulatePermissionFailures: false,
       shouldSimulateBookmarkFailures: false,
       artificialDelay: 0.5
   )
   ```

3. Service Factory
   ```swift
   // Services are automatically created via ServiceFactory
   let securityService = ServiceFactory.createSecurityService(logger: logger)
   let keychainService = ServiceFactory.createKeychainService(logger: logger)
   ```

## Benefits

- Faster development cycles
- Controlled testing environment
- No security credentials needed
- Easy scenario testing
- Reliable test behaviour

## Implementation Notes

- All services conform to the same protocols as production services
- Thread-safe implementations using concurrent dispatch queues
- Comprehensive logging of all operations
- Configurable failure scenarios and delays
- British English used in logs and documentation

## Best Practices

1. Configuration
   - Start with default configuration (no failures)
   - Add specific failure scenarios as needed
   - Use artificial delays to test async behaviour

2. Logging
   - All operations are logged at appropriate levels
   - Check logs to verify behaviour
   - Use logger.debug for detailed operation tracking

3. Error Handling
   - Test both success and failure scenarios
   - Verify error messages are descriptive
   - Ensure proper error propagation
