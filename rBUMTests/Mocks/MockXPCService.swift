//
//  MockXPCService.swift
//  rBUM
//
//  First created: 8 February 2025
//

@testable import Core
@testable import rBUM
import XCTest

class MockXPCService: ResticXPCServiceProtocol {
    var isHealthy: Bool = true
    var isConnected: Bool = true
    var shouldFailConnection: Bool = false
    var operations: [(Date, String)] = []
    
    var connectHandler: (() -> Bool)?
    var disconnectHandler: (() -> Void)?
    var executeCommandHandler: ((String, [String]) async throws -> ProcessResult)?
    var validateAccessHandler: ((URL) async throws -> Bool)?
    var validateCredentialsHandler: ((URL) async throws -> Bool)?
    
    func connect() -> Bool {
        if let handler = connectHandler {
            return handler()
        }
        return !shouldFailConnection
    }
    
    func disconnect() {
        disconnectHandler?()
    }
    
    func executeCommand(_ command: String, arguments: [String]) async throws -> ProcessResult {
        if let handler = executeCommandHandler {
            return try await handler(command, arguments)
        }
        operations.append((Date(), command))
        return ProcessResult(exitCode: 0, output: "", error: "")
    }
    
    func validateAccess(to url: URL) async throws -> Bool {
        if let handler = validateAccessHandler {
            return try await handler(url)
        }
        return true
    }
    
    func validateCredentials(for url: URL) async throws -> Bool {
        if let handler = validateCredentialsHandler {
            return try await handler(url)
        }
        return true
    }
}
