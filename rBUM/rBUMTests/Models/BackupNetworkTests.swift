//
//  BackupNetworkTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupNetwork functionality
struct BackupNetworkTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let urlSession: MockURLSession
        let notificationCenter: MockNotificationCenter
        let networkMonitor: MockNetworkMonitor
        
        init() {
            self.urlSession = MockURLSession()
            self.notificationCenter = MockNotificationCenter()
            self.networkMonitor = MockNetworkMonitor()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            urlSession.reset()
            notificationCenter.reset()
            networkMonitor.reset()
        }
        
        /// Create test network manager
        func createNetwork() -> BackupNetwork {
            BackupNetwork(
                urlSession: urlSession,
                notificationCenter: notificationCenter,
                networkMonitor: networkMonitor
            )
        }
    }
    
    // MARK: - Network Tests
    
    @Test("Test network connectivity", tags: ["network", "connectivity"])
    func testNetworkConnectivity() async throws {
        // Given: Network manager with mock monitor
        let context = TestContext()
        let network = context.createNetwork()
        
        // When: Network becomes available
        context.networkMonitor.setNetworkStatus(true)
        
        // Then: Network status is updated
        #expect(network.isNetworkAvailable)
        #expect(context.notificationCenter.postNotificationCalled)
        #expect(!network.showError)
        
        // When: Network becomes unavailable
        context.networkMonitor.setNetworkStatus(false)
        
        // Then: Network status is updated
        #expect(!network.isNetworkAvailable)
        #expect(context.notificationCenter.postNotificationCalled)
        #expect(!network.showError)
    }
    
    @Test("Test network requests", tags: ["network", "request"])
    func testNetworkRequests() async throws {
        // Given: Network manager with mock session
        let context = TestContext()
        let network = context.createNetwork()
        let request = MockData.Network.validRequest
        
        context.networkMonitor.setNetworkStatus(true)
        context.urlSession.mockResponse = MockData.Network.validResponse
        
        // When: Making network request
        let response = try await network.send(request)
        
        // Then: Request is successful
        #expect(context.urlSession.lastRequest?.url == request.url)
        #expect(response.statusCode == 200)
        #expect(!network.showError)
    }
    
    @Test("Handle network errors", tags: ["network", "error"])
    func testNetworkErrors() async throws {
        // Given: Network manager with failing session
        let context = TestContext()
        let network = context.createNetwork()
        let request = MockData.Network.validRequest
        
        context.networkMonitor.setNetworkStatus(true)
        context.urlSession.shouldFail = true
        context.urlSession.error = MockData.Error.networkError
        
        // When/Then: Network request fails
        #expect(throws: MockData.Error.networkError) {
            _ = try await network.send(request)
        }
        
        #expect(network.showError)
        #expect(network.error as? MockData.Error == MockData.Error.networkError)
    }
    
    @Test("Handle timeout errors", tags: ["network", "timeout"])
    func testTimeoutErrors() async throws {
        // Given: Network manager with timeout
        let context = TestContext()
        let network = context.createNetwork()
        let request = MockData.Network.validRequest
        
        context.networkMonitor.setNetworkStatus(true)
        context.urlSession.shouldTimeout = true
        
        // When/Then: Network request times out
        #expect(throws: URLError(.timedOut)) {
            _ = try await network.send(request)
        }
        
        #expect(network.showError)
        #expect(network.error is URLError)
    }
    
    @Test("Handle offline state", tags: ["network", "offline"])
    func testOfflineState() async throws {
        // Given: Network manager in offline state
        let context = TestContext()
        let network = context.createNetwork()
        let request = MockData.Network.validRequest
        
        context.networkMonitor.setNetworkStatus(false)
        
        // When/Then: Network request fails when offline
        #expect(throws: BackupNetworkError.offline) {
            _ = try await network.send(request)
        }
        
        #expect(!network.showError)
    }
    
    // MARK: - Performance Tests
    
    @Test("Test network performance", tags: ["network", "performance"])
    func testNetworkPerformance() async throws {
        // Given: Network manager with mock session
        let context = TestContext()
        let network = context.createNetwork()
        let request = MockData.Network.validRequest
        
        context.networkMonitor.setNetworkStatus(true)
        context.urlSession.mockResponse = MockData.Network.validResponse
        
        // When: Making multiple requests
        let startTime = Date()
        for _ in 0..<10 {
            _ = try await network.send(request)
        }
        let endTime = Date()
        
        // Then: Requests complete within reasonable time
        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // All requests should complete within 1 second
    }
}

// MARK: - Mock Network Monitor

final class MockNetworkMonitor: NetworkMonitorProtocol {
    private var isAvailable: Bool = false
    private var statusHandler: ((Bool) -> Void)?
    
    func startMonitoring(handler: @escaping (Bool) -> Void) {
        statusHandler = handler
        handler(isAvailable)
    }
    
    func stopMonitoring() {
        statusHandler = nil
    }
    
    func setNetworkStatus(_ available: Bool) {
        isAvailable = available
        statusHandler?(available)
    }
    
    func reset() {
        isAvailable = false
        statusHandler = nil
    }
}
