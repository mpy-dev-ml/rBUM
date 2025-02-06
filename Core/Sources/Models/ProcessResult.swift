//
//  ProcessResult.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Result of a process execution through the XPC service
@objc public final class ProcessResult: NSObject, Codable {
    /// Standard output from the process
    @objc public let output: String
    
    /// Standard error from the process
    @objc public let error: String
    
    /// Process exit code
    @objc public let exitCode: Int
    
    /// Whether the process executed successfully
    @objc public var succeeded: Bool { exitCode == 0 }
    
    @objc public init(output: String, error: String, exitCode: Int) {
        self.output = output
        self.error = error
        self.exitCode = exitCode
        super.init()
    }
    
    // MARK: - Codable Implementation
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        output = try container.decode(String.self, forKey: .output)
        error = try container.decode(String.self, forKey: .error)
        exitCode = try container.decode(Int.self, forKey: .exitCode)
        super.init()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(output, forKey: .output)
        try container.encode(error, forKey: .error)
        try container.encode(exitCode, forKey: .exitCode)
    }
    
    private enum CodingKeys: String, CodingKey {
        case output
        case error
        case exitCode
    }
}
