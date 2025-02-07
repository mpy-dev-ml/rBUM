import Foundation

@available(macOS 13.0, *)
extension ResticXPCService {
    // MARK: - Error Handling
    
    /// Handles errors that occur during XPC operations
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - operation: Optional operation ID associated with the error
    ///   - retryCount: Number of retry attempts made
    /// - Returns: True if the error was handled and operation should be retried
    func handleError(_ error: Error, operation: UUID? = nil, retryCount: Int = 0) -> Bool {
        // Log the error
        logger.error(
            "XPC error occurred: \(error.localizedDescription)",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Update operation status if provided
        if let operation {
            updateOperation(operation, status: .failed, error: error)
        }
        
        // Handle specific error types
        switch error {
        case let xpcError as ResticXPCError:
            return handleXPCError(xpcError, retryCount: retryCount)
            
        case let securityError as SecurityError:
            return handleSecurityError(securityError, retryCount: retryCount)
            
        case let resticError as ResticError:
            return handleResticError(resticError, retryCount: retryCount)
            
        default:
            return handleGenericError(error, retryCount: retryCount)
        }
    }
    
    /// Handles XPC-specific errors
    /// - Parameters:
    ///   - error: The XPC error
    ///   - retryCount: Number of retry attempts made
    /// - Returns: True if the error was handled and operation should be retried
    private func handleXPCError(_ error: ResticXPCError, retryCount: Int) -> Bool {
        switch error {
        case .connectionNotEstablished, .connectionInterrupted:
            // Attempt to reconnect if we haven't exceeded retry limit
            if retryCount < maxRetries {
                do {
                    try setupXPCConnection()
                    return true
                } catch {
                    logger.error(
                        "Failed to re-establish XPC connection: \(error.localizedDescription)",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                }
            }
            
        case .invalidBookmark, .staleBookmark:
            // Request bookmark refresh from security service
            Task {
                await refreshBookmarks()
            }
            
        default:
            break
        }
        
        return false
    }
    
    /// Handles security-related errors
    /// - Parameters:
    ///   - error: The security error
    ///   - retryCount: Number of retry attempts made
    /// - Returns: True if the error was handled and operation should be retried
    private func handleSecurityError(_ error: SecurityError, retryCount: Int) -> Bool {
        switch error {
        case .accessDenied:
            // Request permission refresh from security service
            Task {
                await refreshPermissions()
            }
            
        case .invalidCredentials:
            // Clear cached credentials
            clearCredentials()
            
        default:
            break
        }
        
        return false
    }
    
    /// Handles Restic-specific errors
    /// - Parameters:
    ///   - error: The Restic error
    ///   - retryCount: Number of retry attempts made
    /// - Returns: True if the error was handled and operation should be retried
    private func handleResticError(_ error: ResticError, retryCount: Int) -> Bool {
        switch error {
        case .repositoryLocked:
            // Attempt to unlock if we haven't exceeded retry limit
            if retryCount < maxRetries {
                Task {
                    try await unlockRepository()
                    return true
                }
            }
            
        case .repositoryCorrupted:
            // Attempt repository repair
            Task {
                try await repairRepository()
            }
            
        default:
            break
        }
        
        return false
    }
    
    /// Handles generic errors
    /// - Parameters:
    ///   - error: The generic error
    ///   - retryCount: Number of retry attempts made
    /// - Returns: True if the error was handled and operation should be retried
    private func handleGenericError(_ error: Error, retryCount: Int) -> Bool {
        // Retry transient errors
        if retryCount < maxRetries {
            return isTransientError(error)
        }
        return false
    }
    
    /// Determines if an error is likely transient
    /// - Parameter error: The error to check
    /// - Returns: True if the error is likely transient
    private func isTransientError(_ error: Error) -> Bool {
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return [
                NSURLErrorTimedOut,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet
            ].contains(nsError.code)
            
        case POSIXError.errorDomain:
            return [
                EAGAIN,
                EBUSY,
                ETIMEDOUT
            ].contains(POSIXErrorCode(rawValue: nsError.code)?.rawValue ?? 0)
            
        default:
            return false
        }
    }
    
    // MARK: - Error Recovery
    
    /// Refresh security-scoped bookmarks
    private func refreshBookmarks() async {
        do {
            let bookmarks = try await securityService.refreshBookmarks()
            try startAccessingResources(bookmarks)
        } catch {
            logger.error(
                "Failed to refresh bookmarks: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    /// Refresh security permissions
    private func refreshPermissions() async {
        do {
            try await securityService.refreshPermissions()
        } catch {
            logger.error(
                "Failed to refresh permissions: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
    
    /// Clear cached credentials
    private func clearCredentials() {
        // Implementation depends on credential storage mechanism
    }
    
    /// Unlock a locked repository
    private func unlockRepository() async throws {
        // Implementation depends on Restic command execution
    }
    
    /// Repair a corrupted repository
    private func repairRepository() async throws {
        // Implementation depends on Restic command execution
    }
}
