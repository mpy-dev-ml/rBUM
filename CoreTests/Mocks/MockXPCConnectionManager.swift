import Foundation
@testable import Core

actor MockXPCConnectionManager: XPCConnectionManager {
    private let mockConnection: MockXPCConnection
    private var isConnected: Bool = false

    init(
        mockConnection: MockXPCConnection,
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol
    ) {
        self.mockConnection = mockConnection
        super.init(logger: logger, securityService: securityService)
    }

    override func establishConnection() async throws -> NSXPCConnection {
        if mockConnection.shouldThrowError {
            throw mockConnection.error
        }
        isConnected = true
        return mockConnection
    }

    override func handleInterruption() {
        isConnected = false
        super.handleInterruption()
    }

    override func handleInvalidation() {
        isConnected = false
        super.handleInvalidation()
    }
}
