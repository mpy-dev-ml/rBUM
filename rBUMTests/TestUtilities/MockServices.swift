//
//  MockServices.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

@testable import Core
@testable import rBUM
import XCTest

// MARK: - Mock Logger

final class MockLogger: LoggerProtocol {
    var messages: [String] = []
    var metadata: [[String: LogMetadataValue]] = []
    var privacyLevels: [LogPrivacy] = []
    
    func log(_ message: String, metadata: [String: LogMetadataValue], privacy: LogPrivacy) {
        messages.append(message)
        self.metadata.append(metadata)
        privacyLevels.append(privacy)
    }
}

// MARK: - Mock XPC Service

final class MockXPCService: ResticXPCServiceProtocol {
    var isHealthy: Bool = true
    var isConnected: Bool = true
    var shouldFailConnection: Bool = false
    var operations: [(Date, String)] = []
    
    func connect() async throws {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
    }
    
    func checkHealth() async throws -> Bool {
        isHealthy
    }
}

// MARK: - Mock Keychain Service

final class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true
    var storedCredentials: KeychainCredentials?
    var credentialsToReturn: KeychainCredentials?
    var bookmarkToReturn: Data?
    
    func checkHealth() async throws -> Bool {
        isHealthy
    }
    
    func storeCredentials(_ credentials: KeychainCredentials) throws {
        storedCredentials = credentials
    }
    
    func retrieveCredentials() throws -> KeychainCredentials? {
        credentialsToReturn
    }
    
    func deleteCredentials() throws {
        storedCredentials = nil
        credentialsToReturn = nil
    }
}
