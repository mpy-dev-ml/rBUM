//
//  DevelopmentSecurityService+XPCValidation.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

import Foundation
import os.log

@available(macOS 13.0, *)
public extension DevelopmentSecurityService {
    /// Validates an XPC connection.
    ///
    /// This method simulates XPC validation by:
    /// - Checking for simulated failures
    /// - Adding artificial delays
    /// - Recording the validation attempt
    /// - Updating metrics
    ///
    /// - Parameter connection: The XPC connection to validate
    /// - Returns: `true` if the connection is valid, `false` otherwise
    /// - Throws: `SecurityError.xpcValidationFailed` if validation fails
    func validateXPCConnection(_ connection: NSXPCConnection) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "XPC validation",
            url: nil,
            error: { SecurityError.xpcValidationFailed($0) }
        )

        try await simulator.simulateDelay()

        // Validate connection state
        guard connection.isValid else {
            logger.error("XPC connection is invalid")
            return false
        }

        // Validate audit session
        guard connection.auditSessionIdentifier == au_session_self() else {
            logger.error("XPC connection audit session mismatch")
            return false
        }

        // Validate interface
        guard connection.remoteObjectInterface != nil else {
            logger.error("XPC connection missing remote object interface")
            return false
        }

        // Record successful validation
        operationRecorder.recordOperation(
            url: nil,
            type: .xpcValidation,
            status: .success
        )
        metrics.recordXPCValidation()

        logger.info(
            """
            Validated XPC connection
            Active XPC Connections: \(metrics.activeXPCConnectionCount)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        return true
    }

    /// Validates XPC entitlements.
    ///
    /// This method simulates entitlement validation by:
    /// - Checking for simulated failures
    /// - Adding artificial delays
    /// - Recording the validation attempt
    /// - Updating metrics
    ///
    /// - Parameter connection: The XPC connection to validate entitlements for
    /// - Returns: `true` if entitlements are valid, `false` otherwise
    /// - Throws: `SecurityError.xpcEntitlementValidationFailed` if validation fails
    func validateXPCEntitlements(_ connection: NSXPCConnection) async throws -> Bool {
        try simulator.simulateFailureIfNeeded(
            operation: "XPC entitlement validation",
            url: nil,
            error: { SecurityError.xpcEntitlementValidationFailed($0) }
        )

        try await simulator.simulateDelay()

        // Validate code signing
        guard connection.processIdentifier > 0 else {
            logger.error("Invalid process identifier")
            return false
        }

        // Record successful validation
        operationRecorder.recordOperation(
            url: nil,
            type: .xpcEntitlementValidation,
            status: .success
        )
        metrics.recordXPCEntitlementValidation()

        logger.info(
            """
            Validated XPC entitlements
            Process ID: \(connection.processIdentifier)
            """,
            file: #file,
            function: #function,
            line: #line
        )

        return true
    }
}
