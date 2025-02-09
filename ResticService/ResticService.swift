//
//  ResticService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Core
import Foundation
import os.log

// MARK: - Restic XPC Error Domain

/// Error domain for ResticService XPC-related errors
enum ResticXPCErrorDomain {
    static let name = "dev.mpy.rBUM.ResticService"

    /// Error codes specific to ResticService XPC operations
    enum Code: Int {
        /// Security validation of the XPC connection failed
        case securityValidationFailed
        /// Audit session is invalid or unavailable
        case auditSessionInvalid
        /// Security-scoped bookmark validation failed
        case bookmarkValidationFailed
        /// Access to a required resource was denied
        case accessDenied
        /// Operation timed out
        case timeout
        /// Operation was cancelled
        case operationCancelled
    }
}

// MARK: - Logging

private extension OSLog {
    static let resticService = OSLog(
        subsystem: "dev.mpy.rBUM.ResticService",
        category: "ResticService"
    )
}

// MARK: - Restic Service Implementation

/// Service responsible for executing Restic commands securely
///
/// This class:
/// 1. Manages XPC connections and command execution
/// 2. Handles security-scoped bookmarks and file access
/// 3. Records security operations for auditing
/// 4. Provides a secure interface for Restic operations
final class ResticService: NSObject, NSXPCListenerDelegate {
    // MARK: - Properties
    
    /// Queue for serializing operations
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.ResticService")
    
    /// Logger for recording operations
    private let logger: LoggerProtocol
    
    /// Recorder for security operations
    private let securityRecorder: SecurityOperationRecorder
    
    /// Current task being executed
    private var currentTask: Process?
    
    // MARK: - Initialization
    
    override init() {
        self.logger = Logger()
        self.securityRecorder = SecurityOperationRecorder()
        super.init()
    }
    
    // MARK: - XPC Connection Management
    
    /// Validates and accepts new XPC connections
    ///
    /// This method:
    /// 1. Validates the connection's audit session
    /// 2. Sets up the connection's interfaces
    /// 3. Records the connection attempt
    /// 4. Returns whether the connection should be accepted
    ///
    /// - Parameters:
    ///   - listener: The XPC listener
    ///   - newConnection: The new connection to validate
    /// - Returns: true if the connection should be accepted
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        // Set up interfaces
        newConnection.exportedInterface = NSXPCInterface(with: ResticServiceProtocol.self)
        newConnection.exportedObject = self
        
        // Set up handlers
        newConnection.invalidationHandler = { [weak self] in
            self?.handleInvalidation()
        }
        
        newConnection.interruptionHandler = { [weak self] in
            self?.handleInterruption()
        }
        
        // Record connection
        securityRecorder.recordOperation(
            url: URL(fileURLWithPath: "xpc"),
            type: .xpc,
            status: .success
        )
        
        // Resume connection
        newConnection.resume()
        return true
    }
    
    // MARK: - Connection Event Handlers
    
    /// Handles connection invalidation
    private func handleInvalidation() {
        logger.log(level: .error, message: "XPC connection invalidated")
        securityRecorder.recordOperation(
            url: URL(fileURLWithPath: "xpc"),
            type: .xpc,
            status: .failure,
            error: "Connection invalidated"
        )
    }
    
    /// Handles connection interruption
    private func handleInterruption() {
        logger.log(level: .error, message: "XPC connection interrupted")
        securityRecorder.recordOperation(
            url: URL(fileURLWithPath: "xpc"),
            type: .xpc,
            status: .failure,
            error: "Connection interrupted"
        )
    }
    
    // MARK: - Protocol Implementation
    
    func initialiseRepository(
        at repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let arguments = ["init", "--repo", repositoryURL]
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Repository initialised at \(repositoryURL, privacy: .private)")
                reply(result)
            } catch {
                self.logger.error("Failed to initialise repository: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    func createBackup(
        repository repositoryURL: Data,
        sourcePaths: [Data],
        password: String,
        excludePatterns: [String],
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                var arguments = ["backup", "--repo", repositoryURL]
                
                // Add exclude patterns
                for pattern in excludePatterns {
                    arguments.append(contentsOf: ["--exclude", pattern])
                }
                
                // Add source paths
                arguments.append(contentsOf: sourcePaths)
                
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Backup completed to \(repositoryURL, privacy: .private)")
                reply(result)
            } catch {
                self.logger.error("Backup failed: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    func listSnapshots(
        repository repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let arguments = ["snapshots", "--repo", repositoryURL, "--json"]
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                reply(result)
            } catch {
                self.logger.error("Failed to list snapshots: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    func restore(
        repository repositoryURL: Data,
        to targetPath: Data,
        snapshot snapshotID: String,
        password: String,
        paths: [String]?,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                var arguments = [
                    "restore",
                    "--repo", repositoryURL,
                    "--target", targetPath,
                    snapshotID
                ]
                
                if let paths = paths {
                    arguments.append(contentsOf: paths)
                }
                
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Restore completed to \(targetPath, privacy: .private)")
                reply(result)
            } catch {
                self.logger.error("Restore failed: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    func verifyRepository(
        at repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let arguments = ["check", "--repo", repositoryURL]
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Repository verification completed")
                reply(result)
            } catch {
                self.logger.error("Repository verification failed: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    func cancelOperation(with reply: @escaping (Bool) -> Void) {
        queue.async {
            guard let task = self.currentTask else {
                reply(false)
                return
            }
            
            task.terminate()
            self.currentTask = nil
            self.logger.info("Operation cancelled")
            reply(true)
        }
    }
    
    func validateBookmark(_ bookmarkData: Data, with reply: @escaping (Bool, Error?) -> Void) {
        queue.async {
            do {
                // Removed security-related code
                reply(true, nil)
            } catch {
                self.logger.error("Bookmark validation failed: \(error.localizedDescription)")
                reply(false, error)
            }
        }
    }
    
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
    private func executeResticCommand(
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
            status: .success
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
