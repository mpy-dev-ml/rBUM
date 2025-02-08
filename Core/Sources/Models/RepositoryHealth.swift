//
//  RepositoryHealth.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Foundation

/// Class representing the health status of a repository
@objc public class RepositoryHealth: NSObject, NSSecureCoding {
    /// Status of the repository
    @objc public let status: String
    
    /// Last check timestamp
    @objc public let lastCheck: Date
    
    /// Number of errors found
    @objc public let errorCount: Int
    
    /// Error messages if any
    @objc public let errors: [String]
    
    /// Size consistency check result
    @objc public let sizeConsistent: Bool
    
    /// Index integrity check result
    @objc public let indexIntegrity: Bool
    
    /// Pack files integrity check result
    @objc public let packIntegrity: Bool
    
    /// Initialize a new repository health status
    /// - Parameters:
    ///   - status: Overall status
    ///   - lastCheck: Time of last check
    ///   - errorCount: Number of errors
    ///   - errors: Error messages
    ///   - sizeConsistent: Size consistency
    ///   - indexIntegrity: Index integrity
    ///   - packIntegrity: Pack files integrity
    @objc public init(
        status: String,
        lastCheck: Date,
        errorCount: Int,
        errors: [String],
        sizeConsistent: Bool,
        indexIntegrity: Bool,
        packIntegrity: Bool
    ) {
        self.status = status
        self.lastCheck = lastCheck
        self.errorCount = errorCount
        self.errors = errors
        self.sizeConsistent = sizeConsistent
        self.indexIntegrity = indexIntegrity
        self.packIntegrity = packIntegrity
        super.init()
    }
    
    // MARK: - NSSecureCoding
    
    public static var supportsSecureCoding: Bool { true }
    
    @objc public func encode(with coder: NSCoder) {
        coder.encode(status, forKey: "status")
        coder.encode(lastCheck, forKey: "lastCheck")
        coder.encode(errorCount, forKey: "errorCount")
        coder.encode(errors, forKey: "errors")
        coder.encode(sizeConsistent, forKey: "sizeConsistent")
        coder.encode(indexIntegrity, forKey: "indexIntegrity")
        coder.encode(packIntegrity, forKey: "packIntegrity")
    }
    
    @objc required public init?(coder: NSCoder) {
        guard let status = coder.decodeObject(of: NSString.self, forKey: "status") as String?,
              let lastCheck = coder.decodeObject(of: NSDate.self, forKey: "lastCheck") as Date?,
              let errors = coder.decodeObject(of: NSArray.self, forKey: "errors") as? [String]
        else {
            return nil
        }
        
        self.status = status
        self.lastCheck = lastCheck
        self.errorCount = coder.decodeInteger(forKey: "errorCount")
        self.errors = errors
        self.sizeConsistent = coder.decodeBool(forKey: "sizeConsistent")
        self.indexIntegrity = coder.decodeBool(forKey: "indexIntegrity")
        self.packIntegrity = coder.decodeBool(forKey: "packIntegrity")
        super.init()
    }
}
