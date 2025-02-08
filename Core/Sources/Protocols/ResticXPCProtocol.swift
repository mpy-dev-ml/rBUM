//
//  ResticXPCProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 8 February 2025
//
import Foundation

/// Protocol for XPC communication with Restic service
@objc public protocol ResticXPCProtocol {
    /// Execute a command via XPC
    /// - Parameters:
    ///   - config: Command configuration
    ///   - progress: Progress tracker for the command
    /// - Returns: Result of command execution
    func execute(
        config: XPCCommandConfig,
        progress: ProgressTracker
    ) async throws -> ProcessResult
    
    /// Ping the XPC service to check its availability
    /// - Returns: True if service is available
    func ping() async throws -> Bool
    
    /// Validate XPC service configuration
    /// - Returns: True if configuration is valid
    func validate() async throws -> Bool
    
    /// Check system resources
    /// - Returns: Current system resources
    func checkResources() async throws -> SystemResources
}
