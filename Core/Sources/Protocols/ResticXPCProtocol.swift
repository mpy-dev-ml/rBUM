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
}

/// Error domain and codes for ResticXPC operations
public enum ResticXPCErrorDomain {
    public static let name = "dev.mpy.rBUM.ResticXPC"
    
    public enum Code: Int {
        case interfaceVersionMismatch = 1000
        case securityValidationFailed = 1001
        case auditSessionInvalid     = 1002
        case bookmarkValidationFailed = 1003
        case serviceUnavailable      = 1004
        case commandExecutionFailed  = 1005
        case timeoutExceeded        = 1006
        case accessDenied           = 1007
    }
}
