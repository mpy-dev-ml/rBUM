import Core
import Foundation

/// Protocol for executing system processes
protocol ProcessExecutorProtocol {
    /// Execute a command with the given arguments and environment
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Command arguments
    ///   - environment: Optional environment variables
    ///   - onOutput: Optional callback for process output
    /// - Returns: Process execution result
    /// - Throws: Error if execution fails
    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult
}

/// Result of process execution
struct ProcessResult: Equatable {
    let output: String
    let error: String
    let exitCode: Int

    var succeeded: Bool { exitCode == 0 }
}

/// Errors that can occur during process execution
enum ProcessError: LocalizedError {
    case executionFailed(String)
    case invalidExecutable(String)
    case sandboxViolation(String)
    case timeout(String)
    case environmentError(String)

    var errorDescription: String? {
        switch self {
        case let .executionFailed(message):
            "Process execution failed: \(message)"
        case let .invalidExecutable(path):
            "Invalid executable at path: \(path)"
        case let .sandboxViolation(message):
            "Sandbox violation: \(message)"
        case let .timeout(message):
            "Process timed out: \(message)"
        case let .environmentError(message):
            "Environment error: \(message)"
        }
    }
}

/// Service for executing system processes with sandbox compliance
final class ProcessExecutor: ProcessExecutorProtocol {
    private let fileManager: FileManager
    private let logger: LoggerProtocol
    private let defaultTimeout: TimeInterval
    private let allowedPaths: Set<String>

    init(
        fileManager: FileManager = .default,
        logger: LoggerProtocol = LoggerFactory.createLogger(
            category: "ProcessExecutor"
        ) as! LoggerProtocol,
        defaultTimeout: TimeInterval = 300,
        allowedPaths: Set<String> = [
            "/usr/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
        ]
    ) {
        self.fileManager = fileManager
        self.logger = logger
        self.defaultTimeout = defaultTimeout
        self.allowedPaths = allowedPaths

        logger.debug(
            """
            Initialized ProcessExecutor with allowed paths: \
            \(allowedPaths)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }

    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult {
        // Validate executable path
        guard let executableURL = validateExecutablePath(command) else {
            throw ProcessError.invalidExecutable(command)
        }

        // Create and configure process
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = try sanitizeEnvironment(environment)

        // Set up pipes for output capture
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Start process with timeout
        logger.debug(
            """
            Executing process:
            Command: \(command)
            Arguments: \(arguments.joined(separator: " "))
            Environment: \(environment?.description ?? "default")
            """,
            file: #file,
            function: #function,
            line: #line
        )

        return try await withThrowingTaskGroup(of: ProcessResult.self) { group in
            group.addTask {
                try await self.runProcess(
                    process,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe,
                    onOutput: onOutput
                )
            }

            group.addTask {
                try await self.enforceTimeout(process)
                throw ProcessError.timeout(
                    "Process exceeded timeout of \(self.defaultTimeout) seconds"
                )
            }

            // Return first completed result (success or error)
            return try await group.next() ?? ProcessResult(
                output: "",
                error: "",
                exitCode: -1
            )
        }
    }

    // MARK: - Private Methods

    private func validateExecutablePath(_ path: String) -> URL? {
        let url = URL(fileURLWithPath: path)

        // Check if path is in allowed directories
        guard allowedPaths.contains(where: { url.path.hasPrefix($0) }) else {
            logger.error(
                """
                Executable path not in allowed directories: \
                \(path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            return nil
        }

        // Validate executable exists and is executable
        guard fileManager.fileExists(atPath: url.path),
              fileManager.isExecutableFile(atPath: url.path)
        else {
            logger.error(
                """
                Executable not found or not executable: \
                \(path)
                """,
                file: #file,
                function: #function,
                line: #line
            )
            return nil
        }

        return url
    }

    private func sanitizeEnvironment(
        _ environment: [String: String]?
    ) throws -> [String: String] {
        var sanitized = ProcessInfo.processInfo.environment

        // Remove sensitive environment variables
        let sensitiveKeys = ["SUDO_", "PASSWORD", "TOKEN", "KEY", "SECRET"]
        sanitized = sanitized.filter { key, _ in
            !sensitiveKeys.contains { key.uppercased().contains($0) }
        }

        // Add provided environment variables after validation
        if let environment {
            for (key, value) in environment {
                guard !key.isEmpty else { continue }
                guard !sensitiveKeys.contains(
                    where: { key.uppercased().contains($0) }
                ) else {
                    throw ProcessError.environmentError(
                        "Attempted to set sensitive environment variable: \(key)"
                    )
                }
                sanitized[key] = value
            }
        }

        return sanitized
    }

    private func runProcess(
        _ process: Process,
        outputPipe: Pipe,
        errorPipe: Pipe,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            do {
                process.terminationHandler = { [weak self] process in
                    guard let self else { return }
                    Task {
                        do {
                            let result = try await self.handleProcessTermination(
                                process,
                                outputPipe: outputPipe,
                                errorPipe: errorPipe
                            )
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                try process.run()

                // Set up output handling if needed
                if let onOutput {
                    Task {
                        try await handleProcessOutput(outputPipe, callback: onOutput)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Handles process termination and collects output
    private func handleProcessTermination(
        _ process: Process,
        outputPipe: Pipe,
        errorPipe: Pipe
    ) async throws -> ProcessResult {
        let (outputData, errorData) = try await collectProcessOutput(
            outputPipe: outputPipe,
            errorPipe: errorPipe
        )

        let outputString = String(data: outputData, encoding: .utf8) ?? ""
        let errorString = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            logProcessError(status: process.terminationStatus, error: errorString)
        }

        return ProcessResult(
            output: outputString,
            error: errorString,
            exitCode: Int(process.terminationStatus)
        )
    }

    /// Collects output from process pipes
    private func collectProcessOutput(
        outputPipe: Pipe,
        errorPipe: Pipe
    ) async throws -> (output: Data, error: Data) {
        async let output = outputPipe.fileHandleForReading.readToEnd() ?? Data()
        async let error = errorPipe.fileHandleForReading.readToEnd() ?? Data()
        return try await (output, error)
    }

    /// Handles real-time process output
    private func handleProcessOutput(
        _ pipe: Pipe,
        callback: @escaping (String) -> Void
    ) async throws {
        let handle = pipe.fileHandleForReading
        for try await line in handle.bytes.lines {
            callback(line)
        }
    }

    /// Logs process error information
    private func logProcessError(status: Int32, error: String) {
        logger.error(
            """
            Process failed with status \(status): \(error)
            """,
            file: #file,
            function: #function,
            line: #line
        )
    }

    private func enforceTimeout(_ process: Process) async throws {
        try await Task.sleep(
            nanoseconds: UInt64(defaultTimeout * 1_000_000_000)
        )
        if process.isRunning {
            process.terminate()
            logger.error(
                """
                Process terminated by timeout after \
                \(defaultTimeout) seconds
                """,
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
}
