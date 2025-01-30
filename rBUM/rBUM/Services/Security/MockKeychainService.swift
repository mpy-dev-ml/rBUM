//
//  MockKeychainService.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation

/// Mock implementation of KeychainService for previews and testing
final class MockKeychainService: KeychainServiceProtocol {
    private var passwords: [String: [String: String]] = [:]
    
    func storePassword(_ password: String, forService service: String, account: String) async throws {
        if passwords[service]?[account] != nil {
            throw KeychainError.duplicateItem
        }
        passwords[service] = passwords[service] ?? [:]
        passwords[service]?[account] = password
    }
    
    func retrievePassword(forService service: String, account: String) async throws -> String {
        guard let password = passwords[service]?[account] else {
            throw KeychainError.itemNotFound
        }
        return password
    }
    
    func updatePassword(_ password: String, forService service: String, account: String) async throws {
        guard passwords[service]?[account] != nil else {
            throw KeychainError.itemNotFound
        }
        passwords[service]?[account] = password
    }
    
    func deletePassword(forService service: String, account: String) async throws {
        guard passwords[service]?[account] != nil else {
            throw KeychainError.itemNotFound
        }
        passwords[service]?[account] = nil
    }
}
