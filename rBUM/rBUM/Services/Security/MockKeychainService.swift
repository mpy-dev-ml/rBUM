//
//  MockKeychainService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Mock implementation of KeychainService for testing
final class MockKeychainService: KeychainServiceProtocol {
    /// Store a password in mock storage
    func storePassword(_ password: String, service: String, account: String) async throws {
        if let error = error { throw error }
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        try await store(data, service: service, account: account)
    }
    
    /// Retrieve a password from mock storage
    func retrievePassword(service: String, account: String) async throws -> String {
        if let error = error { throw error }
        let data = try await retrieve(service: service, account: account)
        guard let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionError
        }
        return password
    }
    
    /// Update a password in mock storage
    func updatePassword(_ password: String, service: String, account: String) async throws {
        if let error = error { throw error }
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        try await update(data, service: service, account: account)
    }
    
    /// Delete a password from mock storage
    func deletePassword(service: String, account: String) async throws {
        if let error = error { throw error }
        try await delete(service: service, account: account)
    }
    
    private var storage: [String: Data] = [:]  // In-memory storage
    var error: Error?                          // Simulated error
    
    /// Store data in mock storage
    func store(_ data: Data, service: String, account: String) async throws {
        if let error = error { throw error }
        let key = "\(service):\(account)"
        storage[key] = data
    }
    
    /// Retrieve data from mock storage
    func retrieve(service: String, account: String) async throws -> Data {
        if let error = error { throw error }
        let key = "\(service):\(account)"
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    /// Update data in mock storage
    func update(_ data: Data, service: String, account: String) async throws {
        if let error = error { throw error }
        let key = "\(service):\(account)"
        guard storage[key] != nil else {
            throw KeychainError.itemNotFound
        }
        storage[key] = data
    }
    
    /// Delete data from mock storage
    func delete(service: String, account: String) async throws {
        if let error = error { throw error }
        let key = "\(service):\(account)"
        guard storage[key] != nil else {
            throw KeychainError.itemNotFound
        }
        storage.removeValue(forKey: key)
    }
}
