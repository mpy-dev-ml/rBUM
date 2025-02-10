import Foundation
import Testing

// MARK: - Mock Implementations

final class MockSecurityService: SecurityServiceProtocol {
    func validateXPCConnection(_: NSXPCConnection) async throws -> Bool {
        validateXPCCalled = true
        if shouldSucceed {
            return true
        }
        throw SecurityError.xpcValidationFailed("Mock XPC validation failed")
    }

    var requestPermissionCalled = false
    var createBookmarkCalled = false
    var resolveBookmarkCalled = false
    var startAccessingCalled = false
    var stopAccessingCalled = false
    var validateAccessCalled = false
    var validateXPCCalled = false

    var shouldSucceed = true
    var lastURL: URL?
    var lastBookmark: Data?

    func validateXPCService() async throws -> Bool {
        validateXPCCalled = true
        if shouldSucceed {
            return true
        }
        throw SecurityError.xpcValidationFailed("Mock XPC validation failed")
    }

    func requestPermission(for url: URL) async throws -> Bool {
        requestPermissionCalled = true
        lastURL = url
        if shouldSucceed {
            return true
        }
        throw SecurityError.permissionDenied("Mock permission denied")
    }

    func createBookmark(for url: URL) throws -> Data {
        createBookmarkCalled = true
        lastURL = url
        if shouldSucceed {
            return Data()
        }
        throw SecurityError.bookmarkCreationFailed("Mock bookmark creation failed")
    }

    func resolveBookmark(_ bookmark: Data) throws -> URL {
        resolveBookmarkCalled = true
        lastBookmark = bookmark
        if shouldSucceed {
            return URL(fileURLWithPath: "/mock/path")
        }
        throw SecurityError.bookmarkResolutionFailed("Mock bookmark resolution failed")
    }

    func startAccessing(_ url: URL) throws -> Bool {
        startAccessingCalled = true
        lastURL = url
        if shouldSucceed {
            return true
        }
        throw SecurityError.accessDenied("Mock access denied")
    }

    func stopAccessing(_ url: URL) async throws {
        stopAccessingCalled = true
        lastURL = url
        if !shouldSucceed {
            throw SecurityError.accessDenied("Mock stop accessing failed")
        }
    }

    func validateAccess(to url: URL) async throws -> Bool {
        validateAccessCalled = true
        lastURL = url
        if shouldSucceed {
            return true
        }
        throw SecurityError.accessDenied("Mock validation failed")
    }

    func persistAccess(to _: URL) throws -> Data {
        if shouldSucceed {
            return Data()
        }
        throw SecurityError.bookmarkCreationFailed("Mock persist access failed")
    }
}

struct ResticXPCServiceTests {
    // MARK: - Test Properties

    private var sut: ResticXPCService!
    private var mockLogger: MockLogger!
    private var mockSecurityService: MockSecurityService!

    // MARK: - Setup and Teardown

    @Test
    mutating func setUp() {
        mockLogger = MockLogger()
        mockSecurityService = MockSecurityService()
        sut = ResticXPCService(logger: mockLogger, securityService: mockSecurityService)
    }

    @Test
    mutating func tearDown() {
        sut = nil
        mockLogger = nil
        mockSecurityService = nil
    }

    // MARK: - Interface Tests

    @Test("Should validate XPC service")
    func testXPCServiceValidation() async throws {
        mockSecurityService.shouldSucceed = true
        let result = try await sut.performHealthCheck()
        #expect(result)
        #expect(mockSecurityService.validateXPCCalled)
    }

    @Test("Should fail XPC service validation")
    func testXPCServiceValidationFailure() async throws {
        mockSecurityService.shouldSucceed = false
        await #expect(throws: SecurityError.xpcValidationFailed("Mock XPC validation failed")) {
            _ = try await sut.performHealthCheck()
        }
    }

    // MARK: - Command Execution Tests

    @Test("Should execute command successfully")
    func testCommandExecution() async throws {
        let command = "echo"
        let arguments = ["Hello"]
        let environment: [String: String] = [:]
        let workingDirectory = "/"
        let bookmarks: [String: NSData] = [:]

        mockSecurityService.shouldSucceed = true

        let result = try await sut.executeCommand(
            command,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            bookmarks: bookmarks
        )

        #expect(result.output == "Hello\n")
        #expect(result.exitCode == 0)
    }

    @Test("Should handle command failure")
    func testCommandFailure() async throws {
        let command = "nonexistent"
        let arguments: [String] = []
        let environment: [String: String] = [:]
        let workingDirectory = "/"
        let bookmarks: [String: NSData] = [:]

        mockSecurityService.shouldSucceed = true

        await #expect(throws: ResticXPCError.executionFailed("Command not found")) {
            _ = try await sut.executeCommand(
                command,
                arguments: arguments,
                environment: environment,
                workingDirectory: workingDirectory,
                bookmarks: bookmarks
            )
        }
    }
}
