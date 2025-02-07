//
//  ServiceLifecycle.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Service lifecycle management framework for rBUM.
///
/// The ServiceLifecycle framework provides a comprehensive solution for managing
/// the lifecycle of services within the application. It includes:
/// - State management and transitions
/// - Lifecycle event handling
/// - Error handling and recovery
/// - Validation and safety checks
///
/// Example usage:
/// ```swift
/// class MyService: LifecycleManaged, LoggingService {
///     private(set) var state: ServiceState = .uninitialized
///     let logger: LoggerProtocol
///     
///     init(logger: LoggerProtocol) {
///         self.logger = logger
///     }
///     
///     func performOperation() throws {
///         try validateUsable(for: "performOperation")
///         // Perform operation
///     }
/// }
/// ```
///
/// Implementation notes:
/// 1. Thread-safe state management
/// 2. Comprehensive error handling
/// 3. Proper resource cleanup
/// 4. Detailed logging support
///
/// See also:
/// - `ServiceState`: Possible states of a service
/// - `LifecycleManaged`: Protocol for lifecycle management
/// - `LoggingService`: Protocol for logging support
public enum ServiceLifecycle {}

/// Represents the possible states of a service throughout its lifecycle.
/// Services transition between these states as they are initialised,
/// run, encounter errors, and shut down.
public enum ServiceState {
    /// Service has not yet been initialised
    case uninitialized

    /// Service is currently performing initialisation
    case initializing

    /// Service has successfully initialised and is ready for use
    case ready

    /// Service has encountered an error during operation
    case error(Error)

    /// Service has been shut down and is no longer available
    case shutdown
}

/// Protocol defining the lifecycle management capabilities of a service.
/// Conforming types must implement state management and support
/// proper initialisation and shutdown procedures.
///
/// This protocol is essential for services that need to:
/// - Perform setup operations before use
/// - Clean up resources when no longer needed
/// - Track their operational state
/// - Handle errors gracefully
public protocol LifecycleManaged {
    /// The current state of the service
    var state: ServiceState { get }

    /// Initialises the service and prepares it for use.
    /// This method should be called before any other operations
    /// are performed on the service.
    ///
    /// - Throws: Any error that occurs during initialisation
    func initialize() async throws

    /// Performs an orderly shutdown of the service.
    /// This method should be called when the service is no longer needed
    /// to ensure proper resource cleanup.
    func shutdown() async
}

/// Default implementation of lifecycle management for services that implement logging.
/// This extension provides basic logging of lifecycle events that can be
/// enhanced by concrete implementations.
public extension LifecycleManaged where Self: LoggingService {
    /// Default implementation of service initialisation with logging.
    /// Concrete implementations should override this method to add
    /// their specific initialisation logic.
    ///
    /// - Throws: Any error that occurs during initialisation
    func initialize() async throws {
        logger.info("Initialising service...",
                    file: #file,
                    function: #function,
                    line: #line)
        // Override in concrete implementations
    }

    /// Default implementation of service shutdown with logging.
    /// Concrete implementations should override this method to add
    /// their specific shutdown logic.
    func shutdown() async {
        logger.info("Shutting down service...",
                    file: #file,
                    function: #function,
                    line: #line)
        // Override in concrete implementations
    }
}
