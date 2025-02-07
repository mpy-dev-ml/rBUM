//
//  ResticService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Core
import Foundation
import os.log
import Security

// MARK: - Restic XPC Error Domain

enum ResticXPCErrorDomain {
    static let name = "dev.mpy.rBUM.ResticService"

    enum Code: Int {
        case securityValidationFailed
        case auditSessionInvalid
        case bookmarkValidationFailed
        case accessDenied
        case timeout
    }
}

// MARK: - Command Configuration

@objc(ResticCommandConfig)
final class ResticCommandConfig: NSObject {
    @objc let command: String
    @objc let arguments: [String]
    @objc let environment: [String: String]
    @objc let workingDirectory: String
    @objc let bookmarks: [String: NSData]
    @objc let auditSessionId: au_asid_t
    
    @objc init(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData],
        auditSessionId: au_asid_t
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.bookmarks = bookmarks
        self.auditSessionId = auditSessionId
        super.init()
    }
}

// MARK: - Restic Service Implementation

@objc final class ResticService: BaseService, ResticXPCProtocol {
    func executeCommand(
        config: XPCCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        queue.async {
            do {
                // Validate audit session
                try self.validateAuditSession(config.auditSessionId)

                // Start accessing bookmarked locations
                let accessedURLs = try self.startAccessingBookmarkedLocations(config.bookmarks)
                defer {
                    // Stop accessing bookmarked locations in defer block
                    self.stopAccessingBookmarkedLocations(accessedURLs)
                }

                // Execute the command
                let result = try self.executeResticCommand(
                    config.command,
                    arguments: config.arguments,
                    environment: config.environment,
                    workingDirectory: config.workingDirectory,
                    timeout: config.timeout
                )

                completion(result)
            } catch {
                self.logger.error(
                    "Command execution failed: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                completion(["error": error.localizedDescription])
            }
        }
    }

    @objc func executeResticCommand(
        config: ResticCommandConfig,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        // Implementation using config object
        Task {
            do {
                let result = try await executeCommand(
                    command: config.command,
                    arguments: config.arguments,
                    environment: config.environment,
                    workingDirectory: config.workingDirectory,
                    bookmarks: config.bookmarks,
                    auditSessionId: config.auditSessionId
                )
                completion(result)
            } catch {
                completion(nil)
            }
        }
    }

    @objc func ping(auditSessionId: au_asid_t, completion: @escaping (Bool) -> Void) {
        queue.async {
            do {
                try self.validateClient()
                try self.validateAuditSession(auditSessionId)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    @objc func validateAccess(
        bookmarks: [String: NSData],
        auditSessionId: au_asid_t,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        queue.async {
            do {
                try self.validateClient()
                try self.validateAuditSession(auditSessionId)
                try self.validateBookmarks(bookmarks)
                completion(["valid": true])
            } catch {
                completion(nil)
            }
        }
    }

    // MARK: - Properties

    private let queue: DispatchQueue
    private let allowedBundleIdentifier = "dev.mpy.rBUM"

    // MARK: - Interface Version

    static var interfaceVersion: Int { 1 }

    // MARK: - Initialization

    init() {
        let queue = DispatchQueue(label: "dev.mpy.rBUM.resticservice", qos: .userInitiated)
        let logger = OSLogger(category: "ResticService")
        self.queue = queue
        super.init(logger: logger)
    }

    // MARK: - Security Validation

    private func validateClient() throws {
        // Validate client's code signing
        let requirement = "anchor apple generic and identifier \"\(allowedBundleIdentifier)\""
        guard let connection = NSXPCConnection.current() else {
            logger.error(
                "No XPC connection available",
                file: #file,
                function: #function,
                line: #line
            )
            throw makeError(.securityValidationFailed)
        }

        let pid = connection.processIdentifier

        // Create the security requirement
        var requirementRef: SecRequirement?
        let status = SecRequirementCreateWithString(requirement as CFString, [], &requirementRef)
        guard status == errSecSuccess, let requirement = requirementRef else {
            logger.error(
                "Failed to create security requirement",
                file: #file,
                function: #function,
                line: #line
            )
            throw makeError(.securityValidationFailed)
        }

        // Validate the client's code
        try validateClientCode(pid, requirement: requirement)
    }

    private func validateClientCode(_ pid: pid_t, requirement: SecRequirement) throws {
        // Create SecCode from pid
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: pid] as CFDictionary

        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let codeRef = code,
              SecCodeCheckValidityWithErrors(codeRef, [], requirement, nil) == errSecSuccess
        else {
            logger.error(
                "Failed to create SecCode from pid",
                file: #file,
                function: #function,
                line: #line
            )
            throw makeError(.securityValidationFailed)
        }
    }

    private func validateAuditSession(_ auditSessionId: au_asid_t) throws {
        guard let connection = NSXPCConnection.current(),
              connection.auditSessionIdentifier == auditSessionId
        else {
            logger.error(
                "Audit session validation failed",
                file: #file,
                function: #function,
                line: #line
            )
            throw makeError(.auditSessionInvalid)
        }
    }

    // MARK: - ResticXPCProtocol Implementation

    @objc func validateInterface(completion: @escaping ([String: Any]?) -> Void) {
        queue.async {
            do {
                try self.validateClient()
                completion(["version": Self.interfaceVersion])
            } catch {
                completion(nil)
            }
        }
    }

    // MARK: - Security Helpers

    private func secCodeCreateWithAuditToken(_ token: audit_token_t) throws -> SecCode? {
        var code: SecCode?
        let attributes = [kSecGuestAttributePid: token] as CFDictionary
        let status = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        guard status == errSecSuccess else {
            throw makeError(.securityValidationFailed)
        }
        return code
    }

    // MARK: - Private Methods

    private func makeError(_ code: ResticXPCErrorDomain.Code) -> Error {
        NSError(domain: ResticXPCErrorDomain.name, code: code.rawValue, userInfo: nil)
    }

    private func validateBookmarks(_ bookmarks: [String: NSData]) throws {
        for (_, bookmark) in bookmarks {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark as Data,
                                     options: .withSecurityScope,
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale),
                !isStale
            else {
                throw makeError(.bookmarkValidationFailed)
            }

            guard url.startAccessingSecurityScopedResource() else {
                throw makeError(.accessDenied)
            }
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func startAccessingBookmarkedLocations(_ bookmarks: [String: NSData]) throws -> [URL] {
        var accessedURLs = [URL]()

        for (_, bookmark) in bookmarks {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark as Data,
                                     options: .withSecurityScope,
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale),
                !isStale
            else {
                throw makeError(.bookmarkValidationFailed)
            }

            guard url.startAccessingSecurityScopedResource() else {
                throw makeError(.accessDenied)
            }
            accessedURLs.append(url)
        }

        return accessedURLs
    }

    private func stopAccessingBookmarkedLocations(_ urls: [URL]) {
        for url in urls {
            url.stopAccessingSecurityScopedResource()
        }
    }

    private func executeResticCommand(
        command _: String,
        arguments _: [String],
        environment _: [String: String],
        workingDirectory _: String,
        timeout _: TimeInterval
    ) throws -> [String: Any] {
        // Execute command implementation here
        // This is a placeholder for the actual command execution
        ["success": true]
    }
}

extension ResticService: NSXPCListenerDelegate {
    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        newConnection.exportedObject = self

        // Set up security
        newConnection.setValue(newConnection.processIdentifier, forKeyPath: "auditSessionIdentifier")

        // Start the connection
        newConnection.resume()
        return true
    }

    func run() {
        let listener = NSXPCListener.service()
        listener.delegate = self

        // Start the service
        listener.resume()

        RunLoop.current.run()
    }
}
