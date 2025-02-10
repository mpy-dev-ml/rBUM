import XCTest
@testable import Core
@testable import rBUM

class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true
    var storedCredentials: KeychainCredentials?
    var credentialsToReturn: KeychainCredentials?
    var bookmarkToReturn: Data?

    var saveCredentialsCalled = false
    var savedCredentials: KeychainCredentials?
    var validateCredentialsCalled = false
    var validateCredentialsResult = true
    var hasValidCredentials = true

    func saveCredentials(_ credentials: KeychainCredentials, for url: URL) async throws {
        saveCredentialsCalled = true
        savedCredentials = credentials
        storedCredentials = credentials
    }

    func validateCredentials(for url: URL) async throws -> Bool {
        validateCredentialsCalled = true
        return validateCredentialsResult
    }

    func retrieveCredentials(for url: URL) async throws -> KeychainCredentials? {
        credentialsToReturn ?? storedCredentials
    }

    func deleteCredentials(for url: URL) async throws {
        storedCredentials = nil
    }

    func saveBookmark(_ bookmark: Data, for url: URL) async throws {
        bookmarkToReturn = bookmark
    }

    func retrieveBookmark(for url: URL) async throws -> Data? {
        bookmarkToReturn
    }

    func deleteBookmark(for url: URL) async throws {
        bookmarkToReturn = nil
    }
}
