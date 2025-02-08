@testable import Core
@testable import rBUM
import XCTest

// Re-export Core types
@_exported import enum Core.LogPrivacy
@_exported import struct Core.LogMetadataValue

// Re-export mock implementations
@_exported import MockKeychainService
@_exported import MockLogger
@_exported import MockXPCService

// MARK: - Mock Logger

class MockLogger: LoggerProtocol {
    var messages: [String] = []
    var metadata: [[String: LogMetadataValue]] = []
    var privacyLevels: [LogPrivacy] = []

    func log(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file _: String = #file,
        function _: String = #function,
        line _: Int = #line
    ) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        privacyLevels.append(privacy)
    }

    func containsMessage(_ pattern: String) -> Bool {
        messages.contains { $0.contains(pattern) }
    }

    func clear() {
        messages.removeAll()
        metadata.removeAll()
        privacyLevels.removeAll()
    }
}

// MARK: - Mock Security Service

class MockSecurityService: SecurityServiceProtocol {
    var isHealthy: Bool = true
    var hasAccess: Bool = true
    var shouldFailValidation: Bool = false
    var validatedURLs: [URL] = []
    var requestedURLs: [URL] = []
    var revokedURLs: [URL] = []

    func validateAccess(to url: URL) async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.accessDenied
        }
        validatedURLs.append(url)
        return hasAccess
    }

    func requestAccess(to url: URL) async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.accessDenied
        }
        requestedURLs.append(url)
        return hasAccess
    }

    func revokeAccess(to url: URL) {
        revokedURLs.append(url)
    }

    func validateEncryption() async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.encryptionFailed
        }
        return true
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        validatedURLs.removeAll()
        requestedURLs.removeAll()
        revokedURLs.removeAll()
    }
}

// MARK: - Mock XPC Service

class MockXPCService: ResticXPCServiceProtocol {
    var isHealthy: Bool = true
    var isConnected: Bool = true
    var shouldFailConnection: Bool = false
    var operations: [(Date, String)] = []
    var commandResults: [String: ProcessResult] = [:]
    var errorToThrow: Error?

    func connect() async throws {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        isConnected = true
    }

    func disconnect() {
        isConnected = false
    }

    func validateConnection() async throws -> Bool {
        if let error = errorToThrow {
            throw error
        }
        return isConnected
    }

    func executeCommand(_ command: String, arguments: [String]) async throws -> ProcessResult {
        operations.append((Date(), "\(command) \(arguments.joined(separator: " "))"))
        
        if let error = errorToThrow {
            throw error
        }
        
        return commandResults[command] ?? ProcessResult(
            status: 0,
            standardOutput: "Mock output for \(command)",
            standardError: ""
        )
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        operations.removeAll()
        commandResults.removeAll()
        errorToThrow = nil
    }
}

// MARK: - Mock Keychain Service

class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true
    var storedCredentials: KeychainCredentials?
    var credentialsToReturn: KeychainCredentials?
    var bookmarkToReturn: Data?
    var errorToThrow: Error?

    func addCredentials(_ credentials: KeychainCredentials) throws {
        if let error = errorToThrow {
            throw error
        }
        storedCredentials = credentials
    }

    func updateCredentials(_ credentials: KeychainCredentials) throws {
        if let error = errorToThrow {
            throw error
        }
        storedCredentials = credentials
    }

    func removeCredentials(_ identifier: String) throws {
        if let error = errorToThrow {
            throw error
        }
        storedCredentials = nil
    }

    func getCredentials(for identifier: String) throws -> KeychainCredentials? {
        if let error = errorToThrow {
            throw error
        }
        return credentialsToReturn
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        storedCredentials = nil
        credentialsToReturn = nil
        bookmarkToReturn = nil
        errorToThrow = nil
    }
}
