//
//  RepositoryCredentials.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Class for storing repository access credentials
@objc public class RepositoryCredentials: NSObject, NSSecureCoding {
    /// Repository password
    @objc public let password: String
    
    /// Repository username (optional)
    @objc public let username: String?
    
    /// SSH key path (optional)
    @objc public let sshKeyPath: String?
    
    /// Initialize new repository credentials
    /// - Parameters:
    ///   - password: Repository password
    ///   - username: Optional username
    ///   - sshKeyPath: Optional SSH key path
    @objc public init(
        password: String,
        username: String? = nil,
        sshKeyPath: String? = nil
    ) {
        self.password = password
        self.username = username
        self.sshKeyPath = sshKeyPath
        super.init()
    }
    
    // MARK: - NSSecureCoding
    
    public static var supportsSecureCoding: Bool { true }
    
    @objc public func encode(with coder: NSCoder) {
        coder.encode(password, forKey: "password")
        coder.encode(username, forKey: "username")
        coder.encode(sshKeyPath, forKey: "sshKeyPath")
    }
    
    @objc required public init?(coder: NSCoder) {
        guard let password = coder.decodeObject(of: NSString.self, forKey: "password") as String? else {
            return nil
        }
        
        self.password = password
        self.username = coder.decodeObject(of: NSString.self, forKey: "username") as String?
        self.sshKeyPath = coder.decodeObject(of: NSString.self, forKey: "sshKeyPath") as String?
        super.init()
    }
}
