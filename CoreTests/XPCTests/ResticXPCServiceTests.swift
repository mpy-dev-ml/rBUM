//
//  ResticXPCServiceTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
import Foundation
@testable import rBUM
import XCTest

class ResticXPCServiceTests: XCTestCase {
    var commandService: ResticCommandService!
    var mockLogger: MockLogger!
    var mockSecurityService: MockSecurityService!
    var testDirectory: URL!
    var testRepository: Repository!

    override func setUp() async throws {
        try await super.setUp()

        mockLogger = MockLogger()
        mockSecurityService = MockSecurityService()

        // Create test directory in sandbox-safe location
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM.tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create test repository
        testRepository = Repository(
            path: testDirectory.appendingPathComponent("test-repo"),
            password: "test-password"
        )

        commandService = ResticCommandService(
            logger: mockLogger,
            securityService: mockSecurityService
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()
        try? FileManager.default.removeItem(at: testDirectory)
        commandService = nil
        mockLogger = nil
        mockSecurityService = nil
        testDirectory = nil
        testRepository = nil
    }

    // MARK: - XPC Connection Tests

    func testXPCConnectionEstablishment() async throws {
        // Service should be available after initialization
        let result = try await commandService.executeResticCommand(.version, for: testRepository)
        XCTAssertEqual(result.exitCode, 0)

        // Verify logging
        XCTAssertTrue(mockLogger.messages.contains { message in
            message.level == .debug && message.text.contains("Command environment configured")
        })
    }

    func testXPCConnectionRecovery() async throws {
        // Force connection invalidation
        NotificationCenter.default.post(
            name: NSXPCConnection.invalidationNotification,
            object: nil
        )

        // Service should recover and still work
        let result = try await commandService.executeResticCommand(.version, for: testRepository)
        XCTAssertEqual(result.exitCode, 0)

        // Verify error and recovery logging
        XCTAssertTrue(mockLogger.messages.contains { message in
            message.level == .error && message.text.contains("XPC connection invalidated")
        })
    }

    // MARK: - Command Execution Tests

    func testBasicCommandExecution() async throws {
        // Test version command
        let result = try await commandService.executeResticCommand(.version, for: testRepository)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.standardOutput.contains("restic"))
    }

    func testCommandWithArguments() async throws {
        // Create a test file
        let testFile = testDirectory.appendingPathComponent("test.txt")
        try "test content".write(to: testFile, atomically: true, encoding: .utf8)

        // Test backup command with file
        let result = try await commandService.executeResticCommand(
            .backup([testFile]),
            for: testRepository
        )
        XCTAssertEqual(result.exitCode, 0)
    }

    func testCommandFailure() async throws {
        // Test with invalid repository
        let invalidRepo = Repository(
            path: testDirectory.appendingPathComponent("nonexistent"),
            password: "invalid"
        )

        do {
            _ = try await commandService.executeResticCommand(.check, for: invalidRepo)
            XCTFail("Expected error for invalid repository")
        } catch {
            XCTAssertTrue(error is ResticError)
        }
    }

    // MARK: - Resource Management Tests

    func testResourceAccessTracking() async throws {
        // Setup mock security service expectations
        var accessedURLs: Set<URL> = []
        mockSecurityService.startAccessingHandler = { url in
            accessedURLs.insert(url)
            return true
        }
        mockSecurityService.stopAccessingHandler = { url in
            accessedURLs.remove(url)
        }

        // Execute command
        _ = try? await commandService.executeResticCommand(.check, for: testRepository)

        // Verify all resources were cleaned up
        XCTAssertTrue(accessedURLs.isEmpty)
    }

    func testWorkingDirectoryManagement() async throws {
        // Execute command to ensure working directory is created
        _ = try? await commandService.executeResticCommand(.version, for: testRepository)

        // Verify working directory exists and has correct permissions
        let workingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dev.mpy.rBUM/restic")

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: workingDir.path,
            isDirectory: &isDirectory
        ))
        XCTAssertTrue(isDirectory.boolValue)

        // Verify permissions
        let attributes = try FileManager.default.attributesOfItem(atPath: workingDir.path)
        let permissions = attributes[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o700)
    }

    // MARK: - Error Handling Tests

    func testServiceUnavailableError() async throws {
        // Force service to be unavailable
        commandService = ResticCommandService(
            logger: mockLogger,
            securityService: mockSecurityService
        )

        // Attempt command execution
        do {
            _ = try await commandService.executeResticCommand(.version, for: testRepository)
            XCTFail("Expected error for unavailable service")
        } catch let error as ResticError {
            XCTAssertEqual(error, ResticError.serviceUnavailable)
        }
    }

    func testAccessDeniedError() async throws {
        // Setup mock security service to deny access
        mockSecurityService.startAccessingHandler = { _ in false }

        do {
            _ = try await commandService.executeResticCommand(.check, for: testRepository)
            XCTFail("Expected access denied error")
        } catch let error as ResticError {
            if case .accessDenied = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}

// MARK: - Mock Security Service

class MockSecurityService: SecurityServiceProtocol {
    var startAccessingHandler: ((URL) -> Bool)?
    var stopAccessingHandler: ((URL) -> Void)?

    func startAccessing(_ url: URL) -> Bool {
        startAccessingHandler?(url) ?? true
    }

    func stopAccessing(_ url: URL) {
        stopAccessingHandler?(url)
    }

    // Add other required protocol methods...
}
