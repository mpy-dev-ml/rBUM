import Foundation

extension SecurityService {
    // MARK: - XPC Validation
    
    /// Validate XPC service by performing a ping test
    /// - Returns: True if service is valid
    /// - Throws: SecurityError if validation fails
    public func validateXPCService() async throws -> Bool {
        logger.debug(
            "Validating XPC service",
            file: #file,
            function: #function,
            line: #line
        )

        let isValid = try await xpcService.ping()
        if !isValid {
            logger.error(
                "XPC service validation failed",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.xpcValidationFailed("Service ping returned false")
        }
        return isValid
    }

    /// Validate an XPC connection by checking its configuration and state
    /// - Parameter connection: Connection to validate
    /// - Returns: True if connection is valid
    /// - Throws: SecurityError if validation fails
    public func validateXPCConnection(_ connection: NSXPCConnection) async throws -> Bool {
        logger.debug(
            "Validating XPC connection",
            file: #file,
            function: #function,
            line: #line
        )

        // Verify connection state
        guard connection.invalidationHandler != nil else {
            logger.error(
                "XPC connection is invalidated",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.xpcValidationFailed("XPC connection is invalidated")
        }

        // Verify interface configuration
        guard connection.remoteObjectInterface != nil else {
            logger.error(
                "XPC connection has no remote object interface",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.xpcValidationFailed("XPC connection has no remote object interface")
        }

        // Verify audit session identifier
        guard connection.auditSessionIdentifier != 0 else {
            logger.error(
                "XPC connection has invalid audit session",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.xpcValidationFailed("XPC connection has invalid audit session")
        }

        // Ensure connection is still valid
        if connection.invalidationHandler == nil {
            logger.error(
                "XPC connection is invalidated",
                file: #file,
                function: #function,
                line: #line
            )
            throw SecurityError.xpcValidationFailed("Connection is invalidated")
        }

        return true
    }
}
