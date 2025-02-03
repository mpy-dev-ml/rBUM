import Foundation
import Core
import XCTest

/// Mock XPC service for testing sandbox-compliant command execution
final class MockXPCService {
    var isConnected: Bool = false
    var lastCommand: String?
    var lastBookmark: Data?
    var shouldFailConnection: Bool = false
    var shouldFailExecution: Bool = false
    var accessedURLs: Set<URL> = []
    
    private(set) var commandHistory: [(command: String, bookmark: Data?)] = []
    private(set) var accessStartCount: Int = 0
    private(set) var accessStopCount: Int = 0
}

extension MockXPCService: ResticXPCServiceProtocol {
    func connect() async throws {
        if shouldFailConnection {
            throw SecurityError.xpcConnectionFailed("Mock connection failure")
        }
        isConnected = true
    }
    
    func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        
        if shouldFailExecution {
            throw SecurityError.xpcServiceError("Mock execution failure")
        }
        
        lastCommand = command
        lastBookmark = bookmark
        commandHistory.append((command, bookmark))
        
        return ProcessResult(output: "Mock output", error: "", exitCode: 0)
    }
    
    func startAccessing(_ url: URL) -> Bool {
        accessStartCount += 1
        accessedURLs.insert(url)
        return true
    }
    
    func stopAccessing(_ url: URL) {
        accessStopCount += 1
        accessedURLs.remove(url)
    }
    
    func validatePermissions() async throws -> Bool {
        guard isConnected else {
            throw SecurityError.xpcConnectionFailed("Not connected")
        }
        return true
    }
}
