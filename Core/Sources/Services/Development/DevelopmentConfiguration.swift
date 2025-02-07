//
//  DevelopmentConfiguration.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Configuration for development services to simulate various conditions and failures.
/// This struct provides a comprehensive set of options to simulate different
/// error conditions and performance characteristics during development and testing.
///
/// Use this configuration to:
/// - Test error handling paths
/// - Verify timeout handling
/// - Simulate network delays
/// - Test failure recovery mechanisms
public struct DevelopmentConfiguration {
    /// Whether to simulate permission failures during security operations
    public var shouldSimulatePermissionFailures: Bool
    
    /// Whether to simulate bookmark failures when accessing security-scoped resources
    public var shouldSimulateBookmarkFailures: Bool
    
    /// Whether to simulate access failures when attempting to access protected resources
    public var shouldSimulateAccessFailures: Bool
    
    /// Whether to simulate connection failures in network operations
    public var shouldSimulateConnectionFailures: Bool
    
    /// Whether to simulate command timeout failures during long-running operations
    public var shouldSimulateTimeoutFailures: Bool
    
    /// Whether to simulate command execution failures during restic operations
    public var shouldSimulateCommandFailures: Bool
    
    /// Artificial delay added to async operations (in seconds)
    /// Used to simulate network latency or slow disk operations
    public var artificialDelay: TimeInterval
    
    /// Simulated command execution time (in seconds)
    /// Used to simulate long-running backup or restore operations
    public var commandExecutionTime: TimeInterval
    
    /// Creates a new development configuration with specified simulation parameters.
    ///
    /// - Parameters:
    ///   - shouldSimulatePermissionFailures: If true, simulates permission-related failures
    ///   - shouldSimulateBookmarkFailures: If true, simulates security-scoped bookmark failures
    ///   - shouldSimulateAccessFailures: If true, simulates resource access failures
    ///   - shouldSimulateConnectionFailures: If true, simulates network connection failures
    ///   - shouldSimulateTimeoutFailures: If true, simulates operation timeout failures
    ///   - shouldSimulateCommandFailures: If true, simulates command execution failures
    ///   - artificialDelay: Additional delay in seconds for async operations
    ///   - commandExecutionTime: Simulated execution time in seconds for commands
    public init(
        shouldSimulatePermissionFailures: Bool = false,
        shouldSimulateBookmarkFailures: Bool = false,
        shouldSimulateAccessFailures: Bool = false,
        shouldSimulateConnectionFailures: Bool = false,
        shouldSimulateTimeoutFailures: Bool = false,
        shouldSimulateCommandFailures: Bool = false,
        artificialDelay: TimeInterval = 0,
        commandExecutionTime: TimeInterval = 0
    ) {
        self.shouldSimulatePermissionFailures = shouldSimulatePermissionFailures
        self.shouldSimulateBookmarkFailures = shouldSimulateBookmarkFailures
        self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
        self.shouldSimulateConnectionFailures = shouldSimulateConnectionFailures
        self.shouldSimulateTimeoutFailures = shouldSimulateTimeoutFailures
        self.shouldSimulateCommandFailures = shouldSimulateCommandFailures
        self.artificialDelay = artificialDelay
        self.commandExecutionTime = commandExecutionTime
    }
    
    /// Default configuration with no simulated failures and no delays.
    /// Use this for normal development when simulation of failures is not needed.
    public static let `default` = DevelopmentConfiguration()
}
