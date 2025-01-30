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
    
    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Process execution failed: \(message)"
        case .invalidData:
            return "Invalid data received from process"
        }
    }
    
    static func == (lhs: ProcessError, rhs: ProcessError) -> Bool {
        switch (lhs, rhs) {
        case (.executionFailed(let lhsMessage), .executionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidData, .invalidData):
            return true
        default:
            return false
        }
    }
}

/// Default implementation of ProcessExecutorProtocol
final class ProcessExecutor: ProcessExecutorProtocol {
    private let bufferSize: Int = 4096
    private let logger = Logging.logger(category: "Process")
    
    func execute(
        command: String,
        arguments: [String],
        environment: [String: String]?,
        onOutput: ((String) -> Void)?
    ) async throws -> ProcessResult {
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
        
        try process.run()
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
