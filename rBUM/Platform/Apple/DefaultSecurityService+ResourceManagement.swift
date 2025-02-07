import AppKit
import Core
import Foundation
import Security

/// Extension providing resource management capabilities for DefaultSecurityService
extension DefaultSecurityService {
    // MARK: - Resource Management
    
    /// Starts accessing a security-scoped resource.
    ///
    /// - Parameter url: The URL of the resource to access
    /// - Returns: Boolean indicating whether access was successfully started
    public func startAccessing(_ url: URL) async throws -> Bool {
        let id = UUID()
        let type: SecurityOperationType = .startAccess
        
        return try await withOperation(id: id, type: type) {
            // Check if we have permission
            guard try await checkSecurityScopedAccess(to: url) else {
                return false
            }
            
            // Start accessing resource
            guard url.startAccessingSecurityScopedResource() else {
                return false
            }
            
            // Monitor resource access
            sandboxMonitor.monitorAccess(to: url)
            return true
        }
    }
    
    /// Stops accessing a security-scoped resource.
    ///
    /// - Parameter url: The URL of the resource to stop accessing
    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
        sandboxMonitor.stopMonitoring(url)
    }
    
    /// Performs an operation with proper resource management.
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the operation
    ///   - type: Type of security operation being performed
    ///   - operation: The operation to perform
    /// - Returns: The result of the operation
    internal func withOperation<T>(
        id: UUID,
        type: SecurityOperationType,
        operation: () async throws -> T
    ) async throws -> T {
        // Record operation start
        try await recordOperationStart(id: id, type: type)
        
        do {
            // Perform operation
            let result = try await operation()
            
            // Record successful completion
            try await recordOperationEnd(id: id, type: type, error: nil)
            return result
        } catch {
            // Record failure
            try await recordOperationEnd(id: id, type: type, error: error)
            throw error
        }
    }
    
    /// Records the start of a security operation.
    ///
    /// - Parameters:
    ///   - id: Operation identifier
    ///   - type: Type of operation
    private func recordOperationStart(id: UUID, type: SecurityOperationType) async throws {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.insert(id)
        }
        
        logger.info(
            "Starting security operation: \(type)",
            metadata: ["operationId": "\(id)"],
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    /// Records the end of a security operation.
    ///
    /// - Parameters:
    ///   - id: Operation identifier
    ///   - type: Type of operation
    ///   - error: Optional error if operation failed
    private func recordOperationEnd(
        id: UUID,
        type: SecurityOperationType,
        error: Error?
    ) async throws {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
        
        if let error = error {
            logger.error(
                "Security operation failed: \(type), Error: \(error)",
                metadata: ["operationId": "\(id)"],
                file: #file,
                function: #function,
                line: #line
            )
        } else {
            logger.info(
                "Security operation completed: \(type)",
                metadata: ["operationId": "\(id)"],
                file: #file,
                function: #function,
                line: #line
            )
        }
    }
}
