//
//  ResticCommandService.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Foundation

enum ResticError: Error {
    case commandFailed(String)
    case invalidRepository
    case invalidPassword
    case repositoryNotFound
    case backupFailed(String)
    case restoreFailed(String)
}

class ResticCommandService {
    private let fileManager = FileManager.default
    private let resticPath: String
    
    init() {
        // TODO: Make this configurable in settings
        self.resticPath = "/usr/local/bin/restic"
    }
    
    private func executeCommand(_ arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: resticPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw ResticError.commandFailed(String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func initializeRepository(at path: URL, password: String) async throws {
        let arguments = [
            "init",
            "--repo", path.path,
            "--password-file", "-"
        ]
        
        // TODO: Implement password handling
        try await executeCommand(arguments)
    }
    
    func checkRepository(at path: URL, password: String) async throws -> Bool {
        let arguments = [
            "check",
            "--repo", path.path,
            "--password-file", "-"
        ]
        
        do {
            _ = try await executeCommand(arguments)
            return true
        } catch {
            return false
        }
    }
}
