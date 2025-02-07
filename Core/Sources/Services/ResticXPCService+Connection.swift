import Foundation
import os.log

// MARK: - Connection Management

@available(macOS 13.0, *)
extension ResticXPCService {
    func configureConnection() {
        configureInterfaces()
        configureSecuritySettings()
        configureErrorHandlers()
        configureMessageHandlers()
    }
    
    private func configureInterfaces() {
        connection.remoteObjectInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        
        // Set up allowed classes for secure coding
        let remoteInterface = connection.remoteObjectInterface
        remoteInterface?.setClasses(
            NSSet(array: [NSString.self, NSArray.self, NSDictionary.self]) as! Set<AnyHashable>,
            for: #selector(ResticXPCProtocol.executeCommand(_:)),
            argumentIndex: 0,
            ofReply: false
        )
    }
    
    private func configureSecuritySettings() {
        // Set audit session identifier for security
        connection.auditSessionIdentifier = au_session_self()
        
        // Configure sandbox extensions
        connection.setAccessibilityPermissions([
            .allowFileAccess,
            .allowNetworkAccess
        ])
        
        // Set up security validation
        connection.setValidationHandler { [weak self] in
            self?.validateConnection() ?? false
        }
    }
    
    private func configureErrorHandlers() {
        connection.interruptionHandler = { [weak self] in
            self?.handleInterruption()
        }
        
        connection.invalidationHandler = { [weak self] in
            self?.handleInvalidation()
        }
        
        connection.errorHandler = { [weak self] error in
            self?.handleError(error)
        }
    }
    
    private func configureMessageHandlers() {
        messageHandler = { [weak self] message in
            guard let self = self else {
                throw ResticXPCError.serviceUnavailable
            }
            try await self.handleMessage(message)
        }
        
        commandHandler = { [weak self] command in
            guard let self = self else {
                throw ResticXPCError.serviceUnavailable
            }
            try await self.executeCommand(command)
        }
    }
    
    private func handleInterruption() {
        logger.warning("XPC connection interrupted")
        connectionState = .interrupted
        
        notificationCenter.post(
            name: .xpcConnectionInterrupted,
            object: nil,
            userInfo: ["service": serviceName]
        )
        
        // Attempt to recover
        Task {
            try await recoverConnection()
        }
    }
    
    private func handleInvalidation() {
        logger.error("XPC connection invalidated")
        connectionState = .invalidated
        
        notificationCenter.post(
            name: .xpcConnectionInvalidated,
            object: nil,
            userInfo: ["service": serviceName]
        )
        
        // Clean up resources
        cleanupResources()
    }
    
    private func handleError(_ error: Error) {
        logger.error("XPC connection error", metadata: [
            "error": .string(error.localizedDescription)
        ])
        
        notificationCenter.post(
            name: .xpcConnectionError,
            object: nil,
            userInfo: [
                "service": serviceName,
                "error": error
            ]
        )
        
        // Update metrics
        metrics.recordError()
    }
    
    private func recoverConnection() async throws {
        guard connectionState == .interrupted else {
            return
        }
        
        logger.info("Attempting to recover XPC connection")
        
        // Wait before attempting recovery
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        do {
            try await reconnect()
            connectionState = .connected
            logger.info("XPC connection recovered")
        } catch {
            logger.error("Failed to recover XPC connection", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw ResticXPCError.recoveryFailed(error)
        }
    }
    
    private func cleanupResources() {
        // Cancel any pending operations
        pendingOperations.forEach { $0.cancel() }
        pendingOperations.removeAll()
        
        // Release any held resources
        connection.suspend()
        messageHandler = nil
        commandHandler = nil
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
}
