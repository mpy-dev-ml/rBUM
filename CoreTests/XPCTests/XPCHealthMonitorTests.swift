import Testing
@testable import Core

struct XPCHealthMonitorTests {
    // MARK: - Properties

    let mockLogger = MockLogger()
    let mockSecurityService = MockSecurityService()

    // MARK: - Setup

    func setup() async {
        mockLogger.reset()
        mockSecurityService.reset()
    }

    // MARK: - Tests

    @Test("Health monitor initialises with unknown state")
    func testInitialState() async throws {
        // Arrange
        let connectionManager = XPCConnectionManager(
            logger: mockLogger,
            securityService: mockSecurityService
        )

        // Act
        let monitor = XPCHealthMonitor(
            connectionManager: connectionManager,
            logger: mockLogger
        )

        // Assert
        let status = await monitor.currentStatus
        #expect(status.state == .unknown("Initial state"))
        #expect(status.successfulChecks == 0)
        #expect(status.failedChecks == 0)
    }

    @Test("Health check updates status correctly on success")
    func testSuccessfulHealthCheck() async throws {
        // Arrange
        let mockConnection = MockXPCConnection()
        mockConnection.pingResult = true
        mockConnection.resourcesResult = SystemResources(
            cpuUsage: 20.0,
            memoryUsage: 512_000_000,
            availableDiskSpace: 10_000_000_000,
            activeFileHandles: 50,
            activeConnections: 1
        )

        let connectionManager = MockXPCConnectionManager(
            mockConnection: mockConnection,
            logger: mockLogger,
            securityService: mockSecurityService
        )

        let monitor = XPCHealthMonitor(
            connectionManager: connectionManager,
            logger: mockLogger
        )

        // Act
        await monitor.performHealthCheck()

        // Assert
        let status = await monitor.currentStatus
        #expect(status.state == .healthy)
        #expect(status.successfulChecks == 1)
        #expect(status.failedChecks == 0)
        #expect(status.resources.isWithinLimits)
    }

    @Test("Health check detects degraded performance")
    func testDegradedPerformance() async throws {
        // Arrange
        let mockConnection = MockXPCConnection()
        mockConnection.pingResult = true
        mockConnection.resourcesResult = SystemResources(
            cpuUsage: 90.0, // High CPU usage
            memoryUsage: 512_000_000,
            availableDiskSpace: 10_000_000_000,
            activeFileHandles: 50,
            activeConnections: 1
        )

        let connectionManager = MockXPCConnectionManager(
            mockConnection: mockConnection,
            logger: mockLogger,
            securityService: mockSecurityService
        )

        let monitor = XPCHealthMonitor(
            connectionManager: connectionManager,
            logger: mockLogger
        )

        // Act
        await monitor.performHealthCheck()

        // Assert
        let status = await monitor.currentStatus
        if case let .degraded(reason) = status.state {
            #expect(reason.contains("System resources exceeded limits"))
        } else {
            throw TestError("Expected degraded state")
        }
    }

    @Test("Health check handles connection failure")
    func testConnectionFailure() async throws {
        // Arrange
        let mockConnection = MockXPCConnection()
        mockConnection.shouldThrowError = true
        mockConnection.error = ResticXPCError.connectionNotEstablished

        let connectionManager = MockXPCConnectionManager(
            mockConnection: mockConnection,
            logger: mockLogger,
            securityService: mockSecurityService
        )

        let monitor = XPCHealthMonitor(
            connectionManager: connectionManager,
            logger: mockLogger
        )

        // Act
        await monitor.performHealthCheck()

        // Assert
        let status = await monitor.currentStatus
        if case let .unhealthy(reason) = status.state {
            #expect(reason.contains("connection not established"))
        } else {
            throw TestError("Expected unhealthy state")
        }
        #expect(status.failedChecks == 1)
    }

    @Test("Health monitor stops and starts monitoring correctly")
    func testMonitoringLifecycle() async throws {
        // Arrange
        let connectionManager = XPCConnectionManager(
            logger: mockLogger,
            securityService: mockSecurityService
        )

        let monitor = XPCHealthMonitor(
            connectionManager: connectionManager,
            logger: mockLogger,
            interval: 0.1
        )

        // Act - Start monitoring
        await monitor.startMonitoring()
        try await Task.sleep(nanoseconds: 200_000_000) // Wait 200ms

        // Should have performed at least one health check
        let status1 = await monitor.currentStatus
        #expect(status1.state != .unknown("Initial state"))

        // Stop monitoring
        await monitor.stopMonitoring()

        // Wait and verify no more checks are performed
        try await Task.sleep(nanoseconds: 200_000_000)
        let status2 = await monitor.currentStatus
        #expect(status2.lastChecked == status1.lastChecked)
    }
}

// MARK: - Test Helpers

struct TestError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
