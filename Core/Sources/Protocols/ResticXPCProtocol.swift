import Foundation

/// Protocol defining the XPC interface for Restic operations
@objc public protocol ResticXPCProtocol {
    /// Current interface version
    static var interfaceVersion: Int { get }
    
    /// Validate interface version and security requirements
    /// - Parameter completion: Completion handler with validation result and interface version
    func validateInterface(completion: @escaping ([String: Any]?) -> Void)
    
    /// Execute a command through XPC
    /// - Parameters:
    ///   - command: Command to execute
    ///   - arguments: Command arguments
    ///   - environment: Environment variables
    ///   - workingDirectory: Working directory
    ///   - bookmarks: Security-scoped bookmarks for file access
    ///   - timeout: Timeout in seconds
    ///   - auditSessionId: Audit session identifier for security validation
    ///   - completion: Completion handler with result
    func executeCommand(_ command: String,
                       arguments: [String],
                       environment: [String: String],
                       workingDirectory: String,
                       bookmarks: [String: NSData],
                       timeout: TimeInterval,
                       auditSessionId: au_asid_t,
                       completion: @escaping ([String: Any]?) -> Void)
    
    /// Ping the XPC service with security validation
    /// - Parameters:
    ///   - auditSessionId: Audit session identifier for security validation
    ///   - completion: Completion handler with validation result
    func ping(auditSessionId: au_asid_t, completion: @escaping (Bool) -> Void)
    
    /// Validate access permissions with enhanced security
    /// - Parameters:
    ///   - bookmarks: Security-scoped bookmarks for validation
    ///   - auditSessionId: Audit session identifier for security validation
    ///   - completion: Completion handler with validation result
    func validateAccess(bookmarks: [String: NSData],
                       auditSessionId: au_asid_t,
                       completion: @escaping ([String: Any]?) -> Void)
}

/// Error domain and codes for ResticXPC operations
public enum ResticXPCErrorDomain {
    public static let name = "dev.mpy.rBUM.ResticXPC"
    
    public enum Code: Int {
        case interfaceVersionMismatch = 1000
        case securityValidationFailed = 1001
        case auditSessionInvalid = 1002
        case bookmarkValidationFailed = 1003
        case serviceUnavailable = 1004
        case commandExecutionFailed = 1005
        case timeoutExceeded = 1006
        case accessDenied = 1007
    }
}
