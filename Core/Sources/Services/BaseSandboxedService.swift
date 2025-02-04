import Foundation

/// Base class for services that operate within the sandbox
public class BaseSandboxedService {
    /// Logger for tracking operations
    internal let logger: LoggerProtocol
    
    /// Initialize with a logger
    /// - Parameter logger: Logger for tracking operations
    public init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    /// Validate that the service is operating within sandbox constraints
    /// - Returns: true if the service is properly sandboxed
    public func validateSandboxCompliance() -> Bool {
        // Default implementation assumes compliance
        // Subclasses should override this if they need specific validation
        return true
    }
    
    /// Clean up any resources when the service is being deallocated
    deinit {
        // Default cleanup
        // Subclasses should override this if they need specific cleanup
    }
}
