import Foundation
@testable import Core
@testable import rBUM

final class MockSecurityService: SecurityServiceProtocol {
    // MARK: - Test Properties

    var validateAccessCalled = false
    var validateAccessResult = false
    var lastValidatedURL: URL?

    var requestAccessCalled = false
    var requestAccessResult = false
    var lastRequestedURL: URL?

    // MARK: - SecurityServiceProtocol Implementation

    func validateAccess(to url: URL) async throws -> Bool {
        validateAccessCalled = true
        lastValidatedURL = url
        return validateAccessResult
    }

    func requestAccess(to url: URL) async throws -> Bool {
        requestAccessCalled = true
        lastRequestedURL = url
        return requestAccessResult
    }

    func validateHiddenFileAccess() async throws {
        // Not implemented for tests
    }

    func validateSecurityContext() async throws {
        // Not implemented for tests
    }
}
