//
//  DevelopmentConfiguration.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

import Foundation

/// Configuration options for development services
public struct DevelopmentConfiguration: Equatable, Hashable {
    /// Whether to simulate bookmark-related failures
    public let shouldSimulateBookmarkFailures: Bool
    
    /// Whether to simulate access-related failures
    public let shouldSimulateAccessFailures: Bool
    
    /// Artificial delay in seconds for async operations
    public let artificialDelay: TimeInterval
    
    /// Default configuration values
    public static let `default` = DevelopmentConfiguration()
    
    /// Create a new development configuration
    /// - Parameters:
    ///   - shouldSimulateBookmarkFailures: If true, simulates bookmark operation failures
    ///   - shouldSimulateAccessFailures: If true, simulates access operation failures
    ///   - artificialDelay: Delay in seconds to simulate network latency (default: 0)
    public init(
        shouldSimulateBookmarkFailures: Bool = false,
        shouldSimulateAccessFailures: Bool = false,
        artificialDelay: TimeInterval = 0
    ) {
        self.shouldSimulateBookmarkFailures = shouldSimulateBookmarkFailures
        self.shouldSimulateAccessFailures = shouldSimulateAccessFailures
        self.artificialDelay = artificialDelay
    }
}

// MARK: - CustomStringConvertible

extension DevelopmentConfiguration: CustomStringConvertible {
    public var description: String {
        """
        DevelopmentConfiguration(
            shouldSimulateBookmarkFailures: \(shouldSimulateBookmarkFailures),
            shouldSimulateAccessFailures: \(shouldSimulateAccessFailures),
            artificialDelay: \(artificialDelay)
        )
        """
    }
}
