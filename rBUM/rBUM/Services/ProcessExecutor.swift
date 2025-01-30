//
//  ProcessExecutor.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Protocol for executing system processes
protocol ProcessExecutorProtocol {
    /// Execute a command with arguments and environment variables
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Array of command arguments
    ///   - environment: Optional dictionary of environment variables
    /// - Returns: Process execution result containing output, error, and exit code
    func execute(command: String, arguments: [String], environment: [String: String]?) async throws -> ProcessResult
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
    
    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Process execution failed: \(message)"
        }
    }
    
    static func == (lhs: ProcessError, rhs: ProcessError) -> Bool {
        switch (lhs, rhs) {
        case (.executionFailed(let lhsMessage), .executionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        }
    }
}

/// Default implementation of ProcessExecutorProtocol
final class ProcessExecutor: ProcessExecutorProtocol {
    func execute(command: String, arguments: [String], environment: [String: String]?) async throws -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        if let environment = environment {
            process.environment = environment
        }
        
        try process.run()
        
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
        
        process.waitUntilExit()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        return ProcessResult(output: output, error: error, exitCode: process.terminationStatus)
    }
}
