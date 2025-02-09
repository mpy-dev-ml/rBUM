@testable import Core
import Foundation

final class MockXPCConnection: NSXPCConnection {
    var pingResult: Bool = true
    var resourcesResult = SystemResources(
        cpuUsage: 0,
        memoryUsage: 0,
        availableDiskSpace: 0,
        activeFileHandles: 0,
        activeConnections: 0
    )
    var shouldThrowError: Bool = false
    var error: Error = ResticXPCError.connectionNotEstablished
    
    override init() {
        super.init(machServiceName: "")
    }
    
    override var remoteObjectProxyWithErrorHandler: Any {
        MockResticXPCProtocol(
            pingResult: pingResult,
            resourcesResult: resourcesResult,
            shouldThrowError: shouldThrowError,
            error: error
        )
    }
}

final class MockResticXPCProtocol: NSObject, ResticXPCProtocol {
    private let pingResult: Bool
    private let resourcesResult: SystemResources
    private let shouldThrowError: Bool
    private let error: Error
    
    init(
        pingResult: Bool,
        resourcesResult: SystemResources,
        shouldThrowError: Bool,
        error: Error
    ) {
        self.pingResult = pingResult
        self.resourcesResult = resourcesResult
        self.shouldThrowError = shouldThrowError
        self.error = error
        super.init()
    }
    
    func ping() async throws -> Bool {
        if shouldThrowError {
            throw error
        }
        return pingResult
    }
    
    func validate() async throws -> Bool {
        if shouldThrowError {
            throw error
        }
        return true
    }
    
    func checkResources() async throws -> SystemResources {
        if shouldThrowError {
            throw error
        }
        return resourcesResult
    }
    
    func execute(config: XPCCommandConfig, progress: ProgressTracker) async throws -> ProcessResult {
        if shouldThrowError {
            throw error
        }
        return ProcessResult(status: 0, output: "", error: nil)
    }
}
