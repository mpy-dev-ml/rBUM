import XCTest
@testable import Core
@testable import rBUM

// MARK: - Test Environment

struct TestEnvironment {
    let baseDirectory: URL
    let mockServices: MockServices
    let testFiles: [URL]
}

// MARK: - Test Environment Setup

extension XCTestCase {
    static func setupTestEnvironment() async throws -> TestEnvironment {
        let environment = try await createTestEnvironment()
        try await setupTestDirectories(in: environment)
        try await setupTestFiles(in: environment)
        return environment
    }

    private static func createTestEnvironment() async throws -> TestEnvironment {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rBUMTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )

        return TestEnvironment(
            baseDirectory: baseDirectory,
            mockServices: createMockServices(),
            testFiles: []
        )
    }

    private static func createMockServices() -> MockServices {
        let bookmarkService = MockBookmarkService()
        let securityService = MockSecurityService()
        let keychainService = MockKeychainService()

        return MockServices(
            bookmarkService: bookmarkService,
            securityService: securityService,
            keychainService: keychainService
        )
    }
}

// MARK: - Mock Services Container

struct MockServices {
    let bookmarkService: MockBookmarkService
    let securityService: MockSecurityService
    let keychainService: MockKeychainService
}
