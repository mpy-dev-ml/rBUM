//
//  DevelopmentConfiguration.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Configuration for development services to simulate various conditions
public struct DevelopmentConfiguration {
    /// Whether to simulate permission failures
    public var shouldSimulatePermissionFailures: Bool
    /// Whether to simulate bookmark failures
    public var shouldSimulateBookmarkFailures: Bool
    /// Whether to simulate access failures
    public var shouldSimulateAccessFailures: Bool
    /// Whether to simulate connection failures
    public var shouldSimulateConnectionFailures: Bool
    /// Whether to simulate command timeout failures
    public var shouldSimulateTimeoutFailures: Bool
    /// Whether to simulate command execution failures
    public var shouldSimulateCommandFailures: Bool
    /// Artificial delay for async operations (seconds)
    public var artificialDelay: TimeInterval
    /// Simulated command execution time (seconds)
    public var commandExecutionTime: TimeInterval
    
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
    
    /// Default configuration with no simulated failures and no delay
    public static let `default` = DevelopmentConfiguration()
}