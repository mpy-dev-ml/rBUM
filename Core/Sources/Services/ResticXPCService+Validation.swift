import Foundation
import os.log

// MARK: - Validation

@available(macOS 13.0, *)
extension ResticXPCService {
    /// Validates the XPC connection and service state
    /// - Throws: ResticXPCError if validation fails
    func validateConnection() throws {
        guard let connection = connection else {
            throw ResticXPCError.connectionNotEstablished
        }
        
        // Check connection state
        if connection.invalidationHandler == nil {
            throw ResticXPCError.connectionInvalidated
        }
        
        // Check exported interface
        guard connection.exportedInterface != nil else {
            throw ResticXPCError.invalidInterface("Exported interface not configured")
        }
        
        // Check remote interface
        guard connection.remoteObjectInterface != nil else {
            throw ResticXPCError.invalidInterface("Remote interface not configured")
        }
        
        // Check remote object proxy
        guard connection.remoteObjectProxy != nil else {
            throw ResticXPCError.serviceUnavailable
        }
        
        // Check audit session
        guard connection.auditSessionIdentifier == au_session_self() else {
            throw ResticXPCError.invalidSession
        }
    }
    
    /// Validates command prerequisites before execution
    /// - Parameter command: The command to validate
    /// - Throws: ResticXPCError if validation fails
    func validateCommandPrerequisites(_ command: ResticCommand) async throws {
        // Validate connection
        try validateConnection()
        
        // Validate resources
        try validateResources()
        
        // Validate command
        try validateCommand(command)
        
        // Validate health
        guard try await performHealthCheck() else {
            throw ResticXPCError.unhealthyService
        }
    }
    
    /// Validates a Restic command
    /// - Parameter command: The command to validate
    /// - Throws: ResticXPCError if validation fails
    private func validateCommand(_ command: ResticCommand) throws {
        // Check command
        guard !command.command.isEmpty else {
            throw ResticXPCError.invalidCommand("Command cannot be empty")
        }
        
        // Check working directory
        guard !command.workingDirectory.isEmpty else {
            throw ResticXPCError.invalidCommand("Working directory cannot be empty")
        }
        
        // Check arguments
        for argument in command.arguments where argument.contains("..") {
            throw ResticXPCError.invalidCommand("Arguments cannot contain path traversal")
        }
        
        // Check environment
        for (key, value) in command.environment where key.isEmpty || value.isEmpty {
            throw ResticXPCError.invalidCommand("Environment variables cannot be empty")
        }
    }
    
    /// Validates service configuration
    /// - Throws: ResticXPCError if validation fails
    func validateConfiguration() throws {
        // Check timeout
        guard defaultTimeout > 0 else {
            throw ResticXPCError.invalidConfiguration("Default timeout must be positive")
        }
        
        // Check max retries
        guard maxRetries > 0 else {
            throw ResticXPCError.invalidConfiguration("Max retries must be positive")
        }
        
        // Check interface version
        guard interfaceVersion > 0 else {
            throw ResticXPCError.invalidConfiguration("Interface version must be positive")
        }
        
        // Check queue
        guard queue.label.contains("dev.mpy.rBUM") else {
            throw ResticXPCError.invalidConfiguration("Invalid queue label")
        }
    }
    
    /// Validates service state
    /// - Throws: ResticXPCError if validation fails
    func validateServiceState() throws {
        // Check health
        guard isHealthy else {
            throw ResticXPCError.unhealthyService
        }
        
        // Check configuration
        try validateConfiguration()
        
        // Check connection
        try validateConnection()
        
        // Check resources
        try validateResources()
    }
}
