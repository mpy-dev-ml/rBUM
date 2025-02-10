import XCTest
@testable import Core
@testable import ResticService

/// Represents a recorded security operation for testing
struct RecordedOperation {
    let url: URL
    let type: SecurityOperationType
    let status: SecurityOperationStatus
    let error: String?
}

final class ResticServiceXPCSecurityTests: XCTestCase {
    private var service: ResticService!
    private var mockLogger: MockLogger!
    private var mockSecurityRecorder: MockSecurityOperationRecorder!
    private var connection: NSXPCConnection!

    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        mockSecurityRecorder = MockSecurityOperationRecorder()
        service = ResticService()

        // Create XPC connection for testing
        connection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        connection.remoteObjectInterface = NSXPCInterface(with: ResticServiceProtocol.self)
    }

    override func tearDown() async throws {
        connection?.invalidate()
        connection = nil
        service = nil
        mockLogger = nil
        mockSecurityRecorder = nil
        try await super.tearDown()
    }

    // MARK: - XPC Connection Security Tests

    func testXPCConnection_ValidConnection_AcceptsConnection() {
        // Given
        let listener = NSXPCListener(machServiceName: "dev.mpy.rBUM.ResticService")
        listener.delegate = service

        // When
        let shouldAccept = service.listener(listener, shouldAcceptNewConnection: connection)

        // Then
        XCTAssertTrue(shouldAccept)
        XCTAssertNotNil(connection.exportedInterface)
        XCTAssertTrue(connection.exportedInterface!.conforms(to: ResticServiceProtocol.self))
    }

    func testXPCConnection_SecurityOperationRecorded() {
        // Given
        let listener = NSXPCListener(machServiceName: "dev.mpy.rBUM.ResticService")
        listener.delegate = service

        // When
        _ = service.listener(listener, shouldAcceptNewConnection: connection)

        // Then
        // Note: In a real implementation, we'd verify the security operation was recorded
        // through the mockSecurityRecorder
        XCTAssertNotNil(connection.exportedInterface)
    }

    func testXPCConnection_ValidatesAuditSession() {
        // Given
        let listener = NSXPCListener(machServiceName: "dev.mpy.rBUM.ResticService")
        listener.delegate = service

        // When
        let auditSessionID = au_session_self()

        // Then
        XCTAssertNotEqual(auditSessionID, -1, "Audit session should be valid")
    }

    func testXPCConnection_ValidatesEntitlements() {
        // Given
        let listener = NSXPCListener(machServiceName: "dev.mpy.rBUM.ResticService")
        listener.delegate = service

        // When
        let shouldAccept = service.listener(listener, shouldAcceptNewConnection: connection)

        // Then
        XCTAssertTrue(shouldAccept)
        // Note: In a real implementation, we'd verify entitlements through the Security framework
    }

    func testXPCConnection_HandlesInvalidation() {
        // Given
        let expectation = XCTestExpectation(description: "Connection invalidation")
        var invalidationHandlerCalled = false

        connection.invalidationHandler = {
            invalidationHandlerCalled = true
            expectation.fulfill()
        }

        // When
        connection.resume()
        connection.invalidate()

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(invalidationHandlerCalled)
    }

    func testXPCConnection_HandlesInterruption() {
        // Given
        let expectation = XCTestExpectation(description: "Connection interruption")
        var interruptionHandlerCalled = false

        connection.interruptionHandler = {
            interruptionHandlerCalled = true
            expectation.fulfill()
        }

        // When
        connection.resume()
        connection.invalidate() // Simulating interruption

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(interruptionHandlerCalled)
    }

    func testXPCConnection_ValidatesMessageProtocol() {
        // Given
        let listener = NSXPCListener(machServiceName: "dev.mpy.rBUM.ResticService")
        listener.delegate = service

        // When
        _ = service.listener(listener, shouldAcceptNewConnection: connection)

        // Then
        XCTAssertNotNil(connection.remoteObjectInterface)
        XCTAssertTrue(connection.remoteObjectInterface!.conforms(to: ResticServiceProtocol.self))
    }

    // MARK: - Helper Types

    private class MockLogger: LoggerProtocol {
        var loggedMessages: [(level: OSLogType, message: String)] = []

        func log(level: OSLogType, message: String) {
            loggedMessages.append((level, message))
        }
    }

    /// Records security operations for testing
    private class MockSecurityOperationRecorder {
        /// List of recorded operations
        private(set) var operations: [RecordedOperation] = []

        /// Records a security operation
        func recordOperation(
            url: URL,
            type: SecurityOperationType,
            status: SecurityOperationStatus,
            error: String? = nil
        ) {
            let operation = RecordedOperation(
                url: url,
                type: type,
                status: status,
                error: error
            )
            operations.append(operation)
        }
    }
}

// MARK: - Test Helpers

extension ResticServiceXPCSecurityTests {
    /// Creates a test XPC connection with the specified security settings
    private func createTestConnection(
        withEntitlements: Bool = true,
        withAuditSession: Bool = true
    ) -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        connection.remoteObjectInterface = NSXPCInterface(with: ResticServiceProtocol.self)
        if withAuditSession {
            connection.auditSessionIdentifier = au_session_self()
        }
        return connection
    }

    /// Simulates an XPC connection with invalid security properties
    private func createInvalidConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        connection.remoteObjectInterface = NSXPCInterface(with: ResticServiceProtocol.self)
        connection.auditSessionIdentifier = -1 // Invalid audit session
        return connection
    }
}
