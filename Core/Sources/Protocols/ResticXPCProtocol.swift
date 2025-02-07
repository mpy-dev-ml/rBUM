//
//  ResticXPCProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Configuration for XPC command execution
@objc public class XPCCommandConfig: NSObject {
    public let command: String
    public let arguments: [String]
    public let environment: [String: String]
    public let workingDirectory: String
    public let bookmarks: [String: NSData]
    public let timeout: TimeInterval
    public let auditSessionId: au_asid_t

    public init(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData],
        timeout: TimeInterval,
        auditSessionId: au_asid_t
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.bookmarks = bookmarks
        self.timeout = timeout
        self.auditSessionId = auditSessionId
        super.init()
    }
}

/// Protocol defining the XPC interface for Restic operations
@objc public protocol ResticXPCProtocol {
    /// Current interface version
    static var interfaceVersion: Int { get }

    /// Validate interface version and security requirements
    /// - Parameter completion: Completion handler with validation result and interface version
    func validateInterface(
        completion: @escaping ([String: Any]?) -> Void
    )

    /// Execute a command through XPC
    /// - Parameters:
    ///   - config: Configuration for command execution
    ///   - completion: Completion handler with result
    func executeCommand(
        config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    )

    /// Ping the XPC service with security validation
    /// - Parameters:
    ///   - auditSessionId: Audit session identifier for security validation
    ///   - completion: Completion handler with validation result
    func ping(
        auditSessionId: au_asid_t,
        completion: @escaping (Bool) -> Void
    )

    /// Validate access permissions with enhanced security
    /// - Parameters:
    ///   - bookmarks: Security-scoped bookmarks for validation
    ///   - auditSessionId: Audit session identifier for security validation
    ///   - completion: Completion handler with validation result
    func validateAccess(
        bookmarks: [String: NSData],
        auditSessionId: au_asid_t,
        completion: @escaping ([String: Any]?) -> Void
    )

    /// Executes a Restic command with the provided arguments and environment
    /// - Parameters:
    ///   - command: The Restic command to execute
    ///   - environment: Environment variables for the command
    /// - Returns: The result of the command execution
    /// - Throws: If the command execution fails
    func executeCommand(_ command: ResticCommand) async throws -> ProcessResult

    /// Validates the connection to the XPC service
    /// - Returns: True if the connection is valid and operational
    /// - Throws: If the validation fails or connection is invalid
    func validateConnection() async throws -> Bool

    /// Performs a health check of the XPC service
    /// - Returns: The current health status of the service
    /// - Throws: If the health check fails
    func checkHealth() async throws -> HealthStatus

    /// Cleans up resources used by the XPC service
    /// - Parameter force: If true, forces cleanup even if resources are in use
    /// - Throws: If the cleanup operation fails
    func cleanup(force: Bool) async throws
}

/// Error domain and codes for ResticXPC operations.
/// Used to identify and categorise errors that occur during XPC communication and command execution.
public enum ResticXPCErrorDomain {
    /// The error domain identifier for ResticXPC operations
    public static let name = "dev.mpy.rBUM.ResticXPC"

    /// Error codes specific to ResticXPC operations.
    /// Each code represents a distinct type of error that can occur during XPC communication.
    public enum Code: Int {
        /// The XPC interface version of the client does not match the service
        case interfaceVersionMismatch = 1000
        
        /// Security validation checks failed during XPC communication
        case securityValidationFailed = 1001
        
        /// The audit session is invalid or has expired
        case auditSessionInvalid = 1002
        
        /// Security-scoped bookmark validation failed
        case bookmarkValidationFailed = 1003
        
        /// The XPC service is not available or cannot be reached
        case serviceUnavailable = 1004
        
        /// Command execution through XPC failed
        case commandExecutionFailed = 1005
        
        /// The operation exceeded its specified timeout
        case timeoutExceeded = 1006
        
        /// Access to requested resources was denied
        case accessDenied = 1007
    }
}
