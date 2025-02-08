//
//  ResticCommand.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Foundation

/// Class representing a Restic command for XPC execution
@objc public class ResticCommand: NSObject, NSSecureCoding {
    /// Command to execute
    @objc public let command: String
    
    /// Command arguments
    @objc public let arguments: [String]
    
    /// Environment variables
    @objc public let environment: [String: String]
    
    /// Working directory
    @objc public let workingDirectory: String?
    
    /// Security-scoped bookmarks
    @objc public let bookmarks: [String: NSData]
    
    /// Initialize a new Restic command
    /// - Parameters:
    ///   - command: Command to execute
    ///   - arguments: Command arguments
    ///   - environment: Environment variables
    ///   - workingDirectory: Working directory
    ///   - bookmarks: Security-scoped bookmarks
    @objc public init(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String?,
        bookmarks: [String: NSData]
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.bookmarks = bookmarks
        super.init()
    }
    
    // MARK: - NSSecureCoding
    
    public static var supportsSecureCoding: Bool { true }
    
    @objc public func encode(with coder: NSCoder) {
        coder.encode(command, forKey: "command")
        coder.encode(arguments, forKey: "arguments")
        coder.encode(environment, forKey: "environment")
        coder.encode(workingDirectory, forKey: "workingDirectory")
        coder.encode(bookmarks, forKey: "bookmarks")
    }
    
    @objc required public init?(coder: NSCoder) {
        guard let command = coder.decodeObject(of: NSString.self, forKey: "command") as String?,
              let arguments = coder.decodeObject(of: NSArray.self, forKey: "arguments") as? [String],
              let environment = coder.decodeObject(of: NSDictionary.self, forKey: "environment") as? [String: String],
              let bookmarks = coder.decodeObject(of: NSDictionary.self, forKey: "bookmarks") as? [String: NSData]
        else {
            return nil
        }
        
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = coder.decodeObject(of: NSString.self, forKey: "workingDirectory") as String?
        self.bookmarks = bookmarks
        super.init()
    }
}
