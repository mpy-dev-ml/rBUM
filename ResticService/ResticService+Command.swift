import Core
import Foundation
import os.log

// MARK: - Command Execution

extension ResticService {
    /// Executes a Restic command with the specified arguments and environment
    ///
    /// This method:
    /// 1. Creates and configures a Process instance
    /// 2. Records the execution as a security operation
    /// 3. Captures command output and error
    /// 4. Records the operation result
    ///
    /// - Parameters:
    ///   - arguments: Command line arguments for Restic
    ///   - environment: Environment variables for the command
    /// - Returns: A ResticCommandResult containing output and status
    /// - Throws: If the command fails to start or execute
    func executeResticCommand(
        arguments: [String],
        environment: [String: String]
    ) throws -> ResticCommandResult {
        let task = Process()
        currentTask = task

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/restic")
        task.arguments = arguments
        task.environment = environment
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        securityRecorder.recordOperation(
            url: task.executableURL!,
            type: .xpc,
            status: .success,
            error: nil
        )

        try task.run()
        task.waitUntilExit()

        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        currentTask = nil

        let status: SecurityOperationStatus = task.terminationStatus == 0 ? .success : .failure
        securityRecorder.recordOperation(
            url: task.executableURL!,
            type: .xpc,
            status: status,
            error: error.isEmpty ? nil : error
        )

        return ResticCommandResult(
            output: output,
            error: error,
            exitCode: task.terminationStatus
        )
    }
}
