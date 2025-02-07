//
//  DevelopmentXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Development mock implementation of ResticXPCProtocol
/// Provides simulated XPC service behaviour for development and testing
public final class DevelopmentXPCService: ResticXPCProtocol {
    // MARK: - Properties

    /// Logger for service operations
    private let logger: LoggerProtocol

    /// Queue for synchronizing access to shared resources
    private let queue = DispatchQueue(
        label: "dev.mpy.rBUM.developmentXPC",
        attributes: .concurrent
    )

    /// Lock for thread-safe access to shared resources
    private let lock = NSLock()

    /// Configuration for development behavior
    private let configuration: DevelopmentConfiguration

    /// Current interface version
    public static let interfaceVersion: Int = 1

    // MARK: - Initialization

    /// Initialize the development XPC service
    /// - Parameters:
    ///   - logger: Logger for service operations
    ///   - configuration: Configuration for development behavior
    public init(
        logger: LoggerProtocol,
        configuration: DevelopmentConfiguration = .default
    ) {
        self.logger = logger
        self.configuration = configuration

        logger.info(
            """
            Initialised DevelopmentXPCService with configuration:
            \(String(describing: configuration))
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }

    // MARK: - Private Methods

    /// Thread-safe access to shared resources
    /// - Parameter action: Action to perform with shared resources
    /// - Returns: Result of the action
    private func withThreadSafety<T>(_ action: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try action()
    }

    /// Simulate connection failure if configured
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - completion: Completion handler to call with failure result
    private func simulateConnectionFailureIfNeeded<T>(
        operation: String,
        completion: @escaping (T?) -> Void
    ) -> Bool {
        guard configuration.shouldSimulateConnectionFailures else {
            return false
        }

        logger.error(
            """
            Simulating connection failure for operation: \
            \(operation)
            """,
            file: #file,
            function: #function,
            line: #line
        )
        completion(nil)
        return true
    }

    // MARK: - ResticXPCProtocol Implementation

    public func validateInterface(
        completion: @escaping ([String: Any]?) -> Void
    ) {
        if simulateConnectionFailureIfNeeded(
            operation: "interface validation",
            completion: completion
        ) {
            return
        }

        logger.debug(
            "Validating interface version: \(Self.interfaceVersion)",
            file: #file,
            function: #function,
            line: #line
        )

        completion(["version": Self.interfaceVersion])
    }

    public func validateAccess(
        bookmarks: [String: NSData],
        auditSessionId: au_asid_t,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        if simulateConnectionFailureIfNeeded(
            operation: "access validation",
            completion: completion
        ) {
            return
        }

        logger.debug(
            """
            Validating access:
            Bookmarks: \(bookmarks.keys.joined(separator: ", "))
            Audit Session ID: \(auditSessionId)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        // In development mode, we always validate access successfully
        let result = bookmarks.keys.reduce(
            into: [String: Bool]()
        ) { dict, key in
            dict[key] = true
        }

        completion(["validation": result])
    }

    public func executeCommand(
        _ command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData],
        timeout: TimeInterval,
        auditSessionId: au_asid_t,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        let config = XPCCommandConfig(
            command: command,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            bookmarks: bookmarks,
            timeout: timeout,
            auditSessionId: auditSessionId
        )

        executeCommand(config: config, completion: completion)
    }

    public func executeCommand(
        config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        if simulateConnectionFailureIfNeeded(
            operation: "command execution",
            completion: completion
        ) {
            return
        }

        logger.debug(
            """
            Executing command:
            Command: \(config.command)
            Arguments: \(config.arguments.joined(separator: " "))
            Working Directory: \(config.workingDirectory)
            Environment Variables: \(config.environment.keys.joined(separator: ", "))
            Bookmarks: \(config.bookmarks.keys.joined(separator: ", "))
            Timeout: \(config.timeout)
            Audit Session ID: \(config.auditSessionId)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        queue.async {
            // Simulate artificial delay
            if self.configuration.artificialDelay > 0 {
                Thread.sleep(
                    forTimeInterval: self.configuration.artificialDelay
                )
            }

            // Simulate command execution time
            Thread.sleep(
                forTimeInterval: self.configuration.commandExecutionTime
            )

            // Simulate timeout if execution time exceeds timeout
            if self.configuration.commandExecutionTime > config.timeout ||
                self.configuration.shouldSimulateTimeoutFailures
            {
                self.logger.error(
                    """
                    Simulating timeout failure for command: \
                    \(config.command)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                completion(nil)
                return
            }

            // Simulate command failure if configured
            if self.configuration.shouldSimulateCommandFailures {
                self.logger.error(
                    """
                    Simulating command failure for: \
                    \(config.command)
                    """,
                    file: #file,
                    function: #function,
                    line: #line
                )
                completion([
                    "success": false,
                    "error": "Simulated command failure",
                    "exitCode": 1,
                ])
                return
            }

            // Simulate successful command execution
            self.logger.info(
                """
                Successfully executed command: \
                \(config.command)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            completion([
                "success": true,
                "output": "Simulated output for command: \(config.command)",
                "exitCode": 0,
            ])
        }
    }

    public func ping(
        auditSessionId: au_asid_t,
        completion: @escaping (Bool) -> Void
    ) {
        if simulateConnectionFailureIfNeeded(
            operation: "ping",
            completion: { _ in completion(false) }
        ) {
            return
        }

        logger.debug(
            """
            Received ping request:
            Audit Session ID: \(auditSessionId)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        completion(true)
    }
}

/// Configuration for XPC commands
struct XPCCommandConfig {
    /// The command to execute
    let command: String
    /// Arguments to pass to the command
    let arguments: [String]
    /// Environment variables to set for the command
    let environment: [String: String]
    /// Working directory for the command
    let workingDirectory: String
    /// Bookmarks to use for the command
    let bookmarks: [String: NSData]
    /// Timeout for the command execution
    let timeout: TimeInterval
    /// Audit session ID for the command
    let auditSessionId: au_asid_t
}
