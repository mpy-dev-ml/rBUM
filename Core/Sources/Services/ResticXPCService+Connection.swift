import Foundation
import os.log

// MARK: - Connection Management
@available(macOS 13.0, *)
extension ResticXPCService {
    func configureConnection() {
        // Set up error handling
        connection.interruptionHandler = { [weak self] in
            self?.handleError(ResticXPCError.serviceUnavailable)
        }
        
        connection.invalidationHandler = { [weak self] in
            self?.handleError(ResticXPCError.connectionFailed)
        }
    }
    
    func validateInterface() {
        guard let service = connection.remoteObjectProxy as? ResticXPCServiceProtocol else {
            handleError(ResticXPCError.connectionFailed)
            return
        }
        
        Task {
            if await service.ping() {
                self.isHealthy = true
            } else {
                handleError(ResticXPCError.serviceUnavailable)
            }
        }
    }
    
    func handleError(_ error: Error) {
        isHealthy = false
        logger.error(
            "XPC service error: \(error.localizedDescription)",
            file: #file,
            function: #function,
            line: #line
        )
        // Implement recovery strategy based on error type
        if case ResticXPCError.interfaceVersionMismatch = error {
            // Handle version mismatch
            connection.invalidate()
        }
    }
    
    func handleInvalidation() {
        logger.error(
            "XPC connection invalidated",
            file: #file,
            function: #function,
            line: #line
        )
        cleanupResources()
        isHealthy = false
    }
    
    func handleInterruption() {
        logger.error(
            "XPC connection interrupted",
            file: #file,
            function: #function,
            line: #line
        )
        cleanupResources()
        isHealthy = false
    }
}
