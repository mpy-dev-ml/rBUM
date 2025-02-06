//
//  StorageServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//


//
//  StorageServiceProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation

/// Protocol for managing persistent storage operations
public protocol StorageServiceProtocol {
    /// Save data to storage
    /// - Parameters:
    ///   - data: Data to save
    ///   - key: Storage key
    /// - Throws: StorageError if save fails
    func save(_ data: Data, forKey key: String) throws
    
    /// Load data from storage
    /// - Parameter key: Storage key
    /// - Returns: Retrieved data
    /// - Throws: StorageError if load fails
    func load(forKey key: String) throws -> Data
    
    /// Delete data from storage
    /// - Parameter key: Storage key
    /// - Throws: StorageError if deletion fails
    func delete(forKey key: String) throws
}

/// Error types for storage operations
public enum StorageError: LocalizedError {
    case fileOperationFailed(String)
    case invalidData
    case accessDenied
    case notFound
    
    public var errorDescription: String? {
        switch self {
        case .fileOperationFailed(let operation):
            return "File operation failed: \(operation)"
        case .invalidData:
            return "Invalid data format"
        case .accessDenied:
            return "Access denied"
        case .notFound:
            return "Data not found"
        }
    }
}
