//
//  KeychainCredentials.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Represents credentials stored in the Keychain
public struct KeychainCredentials: Codable {
    /// The username or account name
    public let username: String
    
    /// The password or secret
    public let password: String
    
    /// Additional metadata if needed
    public let metadata: [String: String]?
    
    public init(username: String, password: String, metadata: [String: String]? = nil) {
        self.username = username
        self.password = password
        self.metadata = metadata
    }
}
