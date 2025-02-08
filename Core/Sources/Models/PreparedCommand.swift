//
//  PreparedCommand.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//
import Foundation

/// A prepared command ready for execution
@objc public class PreparedCommand: NSObject {
    /// The command to execute
    @objc public let command: String
    
    /// Arguments to pass to the command
    @objc public let arguments: [String]
    
    /// Environment variables for the command
    @objc public let environment: [String: String]
    
    /// Working directory for the command
    @objc public let workingDirectory: String
    
    /// Initialize a new prepared command
    /// - Parameters:
    ///   - command: The command to execute
    ///   - arguments: Arguments to pass to the command
    ///   - environment: Environment variables for the command
    ///   - workingDirectory: Working directory for the command
    @objc public init(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        super.init()
    }
}
