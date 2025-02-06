
## Usage

1. Development Environment
   - Services automatically used in DEBUG builds
   - All operations logged for debugging
   - No actual security credentials needed

2. Configuration
   - Each service has configurable behaviour
   - Success/failure scenarios can be simulated
   - Latency can be artificially added

3. Benefits
   - Faster development cycles
   - Controlled testing environment
   - Reliable test behaviour
   - Easy scenario testing

## Implementation Notes

- All mock services conform to the same protocols as production services
- Thread-safe implementations
- Clear error messages
- Comprehensive logging
- Easy configuration options

## Example Usage

```swift
#if DEBUG
let securityService = DevelopmentSecurityService(
    logger: logger,
    shouldSimulateFailures: false
)
#else
let securityService = DefaultSecurityService(...)
#endif
