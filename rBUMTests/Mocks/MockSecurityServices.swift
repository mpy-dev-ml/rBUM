//
//  MockSecurityServices.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

@testable import Core
@testable import rBUM
import XCTest

// MARK: - Mock Keychain Service

class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true
    var storedCredentials: KeychainCredentials?
    var credentialsToReturn: KeychainCredentials?
    var bookmarkToReturn: Data?
    var dataToReturn: Data?
    var storedBookmarks: [URL: Data] = [:]
    var storedPasswords: [String: [String: Data]] = [:]

    func storeCredentials(_ credentials: KeychainCredentials) throws {
        storedCredentials = credentials
    }

    func retrieveCredentials() throws -> KeychainCredentials {
        guard let credentials = credentialsToReturn else {
            throw KeychainError.itemNotFound
        }
        return credentials
    }

    func deleteCredentials() throws {
        storedCredentials = nil
        credentialsToReturn = nil
    }

    func storeBookmark(_ bookmark: Data, for url: URL) throws {
        storedBookmarks[url] = bookmark
    }

    func retrieveBookmark(for url: URL) throws -> Data {
        if let bookmark = storedBookmarks[url] {
            return bookmark
        }
        return bookmarkToReturn ?? Data()
    }

    func deleteBookmark(for url: URL) throws {
        storedBookmarks.removeValue(forKey: url)
    }

    func storeGenericPassword(_ password: Data, service: String, account: String) throws {
        if storedPasswords[service] == nil {
            storedPasswords[service] = [:]
        }
        storedPasswords[service]?[account] = password
    }

    func retrieveGenericPassword(service: String, account: String) throws -> Data {
        if let password = storedPasswords[service]?[account] {
            return password
        }
        guard let data = dataToReturn else {
            throw KeychainError.itemNotFound
        }
        return data
    }

    func deleteGenericPassword(service: String, account: String) throws {
        storedPasswords[service]?.removeValue(forKey: account)
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        storedCredentials = nil
        credentialsToReturn = nil
        bookmarkToReturn = nil
        dataToReturn = nil
        storedBookmarks.removeAll()
        storedPasswords.removeAll()
        isHealthy = true
    }
}

// MARK: - Mock Bookmark Service

class MockBookmarkService: BookmarkServiceProtocol {
    var isHealthy: Bool = true
    var isValidBookmark: Bool = false
    var bookmarkedURL: URL?
    var bookmarkToReturn: Data?
    var canStartAccessing: Bool = false
    var stoppedURL: URL?
    var accessedURLs: Set<URL> = []

    func createBookmark(for url: URL, readOnly _: Bool) async throws -> Data {
        bookmarkedURL = url
        return bookmarkToReturn ?? Data()
    }

    func resolveBookmark(_: Data) async throws -> URL {
        guard let url = bookmarkedURL else {
            throw BookmarkError.resolutionFailed("No URL")
        }
        return url
    }

    func startAccessing(_ url: URL) async throws -> Bool {
        if canStartAccessing {
            accessedURLs.insert(url)
        }
        return canStartAccessing
    }

    func stopAccessing(_ url: URL) {
        stoppedURL = url
        accessedURLs.remove(url)
    }

    func validateBookmark(for _: URL) async throws -> Bool {
        isValidBookmark
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        bookmarkedURL = nil
        bookmarkToReturn = nil
        stoppedURL = nil
        accessedURLs.removeAll()
        isHealthy = true
        isValidBookmark = false
        canStartAccessing = false
    }
}

// MARK: - Mock Sandbox Monitor

class MockSandboxMonitor: SandboxMonitorProtocol {
    var isHealthy: Bool = true
    var trackedURL: URL?
    var stoppedURL: URL?
    var trackedResources: Set<URL> = []

    func trackResourceAccess(to url: URL) {
        trackedURL = url
        trackedResources.insert(url)
    }

    func stopTrackingResource(_ url: URL) {
        stoppedURL = url
        trackedResources.remove(url)
    }

    func checkResourceAccess(to url: URL) -> Bool {
        trackedResources.contains(url)
    }

    func performHealthCheck() async -> Bool {
        isHealthy
    }

    func clear() {
        trackedURL = nil
        stoppedURL = nil
        trackedResources.removeAll()
        isHealthy = true
    }
}
