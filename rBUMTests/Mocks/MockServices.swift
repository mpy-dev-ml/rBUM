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

// Re-export Core mocks
@_exported import class Core.MockLogger
@_exported import class Core.MockResticXPCService

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
        isHealthy = true
        hasAccess = true
        shouldFailValidation = false
    }
}
