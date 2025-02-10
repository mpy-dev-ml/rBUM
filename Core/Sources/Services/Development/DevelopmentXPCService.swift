import Foundation

/// Development mock implementation of ResticXPCProtocol
/// Provides simulated XPC service behaviour for development and testing
@objc public final class DevelopmentXPCService: NSObject, ResticXPCProtocol {
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
    @objc public static let interfaceVersion: Int = 1

    // MARK: - Initialization

    /// Initialize the development XPC service
    /// - Parameters:
    ///   - logger: Logger for service operations
    ///   - configuration: Configuration for development behavior
    @objc public init(
        logger: LoggerProtocol,
        configuration: DevelopmentConfiguration = .default
    ) {
        self.logger = logger
        self.configuration = configuration
        super.init()

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

    // MARK: - Command Execution

    /// Execute a command through XPC using a configuration object
    /// - Parameters:
    ///   - config: The command configuration object containing all execution parameters
    ///   - completion: Completion handler with result
    public func executeCommand(config: XPCCommandConfig, completion: @escaping ([String: Any]?) -> Void) {
        if simulateConnectionFailureIfNeeded(completion: completion) {
            return
        }

        if simulateTimeoutIfNeeded(completion: completion) {
            return
        }

        handleCommand(config, completion: completion)
    }

    /// Execute a command through XPC using individual parameters
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    ///   - environment: Environment variables
    ///   - workingDirectory: Working directory for command execution
    ///   - bookmarks: Security-scoped bookmarks
    ///   - timeout: Command timeout
    ///   - auditSessionId: Audit session identifier
    ///   - completion: Completion handler with result
    /// - Note: This method is deprecated. Use `executeCommand(config:completion:)` instead
    @available(*, deprecated, message: "Use executeCommand(config:completion:) instead")
    // swiftlint:disable:next function_parameter_count
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

    private func handleCommand(
        _ config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        logCommandExecution(config)

        queue.async {
            self.processCommand(config, completion: completion)
        }
    }

    private func processCommand(
        _ config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        simulateArtificialDelay()
        simulateExecutionTime()

        if shouldSimulateTimeout(config) {
            handleTimeout(config, completion: completion)
            return
        }

        if configuration.shouldSimulateCommandFailures {
            handleCommandFailure(config, completion: completion)
            return
        }

        handleSuccessfulExecution(config, completion: completion)
    }

    private func logCommandExecution(_ config: XPCCommandConfig) {
        logger.debug(
            """
            Executing command:
            Command: \(config.command)
            Arguments: \(config.arguments.joined(separator: " "))
            Working Directory: \(config.workingDirectory)
            Environment: \(config.environment)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }

    private func simulateArtificialDelay() {
        if configuration.artificialDelay > 0 {
            Thread.sleep(forTimeInterval: configuration.artificialDelay)
        }
    }

    private func simulateExecutionTime() {
        Thread.sleep(forTimeInterval: configuration.commandExecutionTime)
    }

    private func shouldSimulateTimeout(_ config: XPCCommandConfig) -> Bool {
        config.command.contains("timeout")
    }

    private func handleTimeout(
        _ config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        logger.error(
            "Simulating timeout failure for command: \(config.command)",
            file: #file,
            function: #function,
            line: #line
        )
        completion(nil)
    }

    private func handleCommandFailure(
        _ config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        logger.error(
            "Simulating command failure for: \(config.command)",
            file: #file,
            function: #function,
            line: #line
        )
        completion([
            "success": false,
            "error": "Simulated command failure",
            "exitCode": 1,
        ])
    }

    private func handleSuccessfulExecution(
        _ config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        logger.info(
            "Successfully executed command: \(config.command)",
            file: #file,
            function: #function,
            line: #line
        )
        completion([
            "success": true,
            "output": "Simulated command output",
            "exitCode": 0,
        ])
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

/// Configuration for command execution
@objc public class ExecutionConfig: NSObject {
    /// The command to execute
    @objc public let command: String

    /// Arguments for the command
    @objc public let arguments: [String]

    /// Environment variables
    @objc public let environment: [String: String]

    /// Working directory for command execution
    @objc public let workingDirectory: URL

    @objc public init(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        super.init()
    }
}

// MARK: - Errors

/// Error type for development XPC service operations
enum DevelopmentXPCError: LocalizedError {
    case invalidCommand
    case invalidWorkingDirectory
    case invalidBookmark
    case timeout
    case connectionFailed
    case sandboxViolation
    case securityError

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            "Invalid command"
        case .invalidWorkingDirectory:
            "Invalid working directory"
        case .invalidBookmark:
            "Invalid security-scoped bookmark"
        case .timeout:
            "Command execution timed out"
        case .connectionFailed:
            "Failed to establish XPC connection"
        case .sandboxViolation:
            "Sandbox violation detected"
        case .securityError:
            "Security error occurred"
        }
    }
}
