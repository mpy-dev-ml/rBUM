//
//  ProcessExecutor.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import OSLog

/// Protocol for executing system processes
protocol ProcessExecutorProtocol {
    /// Execute a command with arguments and environment variables
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Array of command arguments
    ///   - environment: Optional dictionary of environment variables
    ///   - onOutput: Optional callback for streaming output line by line
    /// - Returns: Process execution result containing output, error, and exit code
    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult
}

/// Result of a process execution
struct ProcessResult {
    /// Standard output from the process
    let output: String
    /// Standard error from the process
    let error: String
    /// Process exit code
    let exitCode: Int32
}

/// Errors that can occur during process execution
enum ProcessError: LocalizedError, Equatable {
    case executionFailed(String)
    case invalidData
    case commandNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Process execution failed: \(message)"
        case .invalidData:
            return "Invalid data received from process"
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        }
    }
    
    static func == (lhs: ProcessError, rhs: ProcessError) -> Bool {
        switch (lhs, rhs) {
        case (.executionFailed(let lhsMessage), .executionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidData, .invalidData):
            return true
        case (.commandNotFound(let lhsCommand), .commandNotFound(let rhsCommand)):
            return lhsCommand == rhsCommand
        default:
            return false
        }
    }
}

/// Default implementation of ProcessExecutorProtocol
final class ProcessExecutor: ProcessExecutorProtocol {
    private let bufferSize: Int = 4096
    private let logger = Logging.logger(category: "Process")
    private let fileManager = FileManager.default
    
    /// Find executable in PATH or at absolute path
    private func findExecutable(_ command: String) -> String? {
        // Common paths for Homebrew executables
        let commonPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        
        logger.debug("Searching for executable: \(command)")
        
        // If it's an absolute path or exists in current directory
        if fileManager.fileExists(atPath: command) {
            logger.debug("Found executable at absolute path: \(command)")
            return command
        }
        
        // Build search paths from PATH environment and common paths
        var searchPaths = Set<String>()
        
        // Add paths from PATH environment
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let envPaths = pathEnv.split(separator: ":").map(String.init)
            searchPaths.formUnion(envPaths)
            logger.debug("Added PATH environment paths: \(envPaths.joined(separator: ":"))")
        }
        
        // Add common paths
        searchPaths.formUnion(commonPaths)
        logger.debug("Added common paths: \(commonPaths.joined(separator: ":"))")
        
        // Search for executable
        for path in searchPaths {
            let fullPath = (path as NSString).appendingPathComponent(command)
            logger.debug("Checking path: \(fullPath)")
            if fileManager.fileExists(atPath: fullPath) {
                logger.debug("Found executable at: \(fullPath)")
                return fullPath
            }
        }
        
        logger.error("Could not find executable: \(command)")
        logger.error("Searched paths: \(searchPaths.joined(separator: ":"))")
        return nil
    }
    
    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult {
        logger.debug("Executing command: \(command)")
        logger.debug("Arguments: \(arguments.joined(separator: " "))")
        logger.debug("Environment: \(environment?.description ?? "none")")
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Use shell to execute the command
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", ([command] + arguments).joined(separator: " ")]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Ensure PATH is included in environment
        var finalEnvironment = environment ?? ProcessInfo.processInfo.environment
        if finalEnvironment["PATH"] == nil {
            finalEnvironment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        }
        process.environment = finalEnvironment
        
        logger.debug("Starting process with shell command: \(process.arguments?.joined(separator: " ") ?? "")")
        
        do {
            try process.run()
        } catch {
            logger.error("Failed to start process: \(error.localizedDescription)")
            throw ProcessError.executionFailed("Failed to start process: \(error.localizedDescription)")
        }
        
        // Use actors to handle concurrent access to buffers
        actor OutputBuffer {
            private var data = Data()
            
            func append(_ newData: Data) {
                data.append(newData)
            }
            
            func getData() -> Data {
                data
            }
        }
        
        let outputBuffer = OutputBuffer()
        let errorBuffer = OutputBuffer()
        
        // Set up output handling
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                Task {
                    await outputBuffer.append(data)
                    if let onOutput = onOutput,
                       let str = String(data: data, encoding: .utf8) {
                        // Split by newlines and process each line
                        str.split(separator: "\n").forEach { line in
                            onOutput(String(line))
                        }
                    }
                }
            }
        }
        
        // Set up error handling
        let errorHandle = errorPipe.fileHandleForReading
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                Task {
                    await errorBuffer.append(data)
                }
            }
        }
        
        process.waitUntilExit()
        
        // Clean up handlers
        outputHandle.readabilityHandler = nil
        errorHandle.readabilityHandler = nil
        
        // Convert buffers to strings
        let outputData = await outputBuffer.getData()
        let errorData = await errorBuffer.getData()
        
        guard let output = String(data: outputData, encoding: .utf8),
              let error = String(data: errorData, encoding: .utf8) else {
            throw ProcessError.invalidData
        }
        
        return ProcessResult(output: output, error: error, exitCode: process.terminationStatus)
    }
}
