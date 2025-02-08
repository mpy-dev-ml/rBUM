//
//  ResticXPCError.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 8 February 2025
//
import Foundation

/// Error domain for Restic XPC errors
@objc public class ResticXPCErrorDomain: NSObject {
    @objc public static let name = "dev.mpy.rBUM.ResticXPCError"
}

/// Error codes for Restic XPC errors
@objc public enum ResticXPCErrorCode: Int {
    case serviceUnavailable = 1000
    case connectionFailed = 1001
    case executionFailed = 1002
    case invalidResponse = 1003
    case timeout = 1004
    case bookmarkInvalid = 1005
    case accessDenied = 1006
    case resourceNotFound = 1007
    case versionMismatch = 1008
    case internalError = 1009
    case invalidArguments = 1010
    case missingEnvironment = 1011
    case unsafeArguments = 1012
    case resourceUnavailable = 1013
}

/// Class representing errors that can occur during Restic XPC service operations
@objc public class ResticXPCError: NSError {
    /// Create a service unavailable error
    @objc public static func serviceUnavailable(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .serviceUnavailable,
            message: message
        )
    }
    
    /// Create a connection failed error
    @objc public static func connectionFailed(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .connectionFailed,
            message: message
        )
    }
    
    /// Create an execution failed error
    @objc public static func executionFailed(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .executionFailed,
            message: message
        )
    }
    
    /// Create an invalid response error
    @objc public static func invalidResponse(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .invalidResponse,
            message: message
        )
    }
    
    /// Create a timeout error
    @objc public static func timeout(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .timeout,
            message: message
        )
    }
    
    /// Create a bookmark invalid error
    @objc public static func bookmarkInvalid(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .bookmarkInvalid,
            message: message
        )
    }
    
    /// Create an access denied error
    @objc public static func accessDenied(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .accessDenied,
            message: message
        )
    }
    
    /// Create a resource not found error
    @objc public static func resourceNotFound(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .resourceNotFound,
            message: message
        )
    }
    
    /// Create a version mismatch error
    @objc public static func versionMismatch(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .versionMismatch,
            message: message
        )
    }
    
    /// Create an internal error
    @objc public static func internalError(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .internalError,
            message: message
        )
    }
    
    /// Create an invalid arguments error
    @objc public static func invalidArguments(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .invalidArguments,
            message: message
        )
    }
    
    /// Create a missing environment error
    @objc public static func missingEnvironment(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .missingEnvironment,
            message: message
        )
    }
    
    /// Create an unsafe arguments error
    @objc public static func unsafeArguments(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .unsafeArguments,
            message: message
        )
    }
    
    /// Create a resource unavailable error
    @objc public static func resourceUnavailable(_ message: String) -> ResticXPCError {
        return ResticXPCError(
            code: .resourceUnavailable,
            message: message
        )
    }
    
    // MARK: - Private
    
    private init(code: ResticXPCErrorCode, message: String) {
        super.init(
            domain: ResticXPCErrorDomain.name,
            code: code.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }
    
    @objc required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
