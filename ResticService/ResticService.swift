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

import Foundation
import Core
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

// MARK: - Restic Service Implementation
@objc final class ResticService: BaseService, ResticXPCProtocol {
    @objc func executeResticCommand(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData],
        auditSessionId: au_asid_t,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        queue.async {
            do {
                try self.validateClient()
                try self.validateAuditSession(auditSessionId)
                try self.validateBookmarks(bookmarks)
                
                // Execute command implementation here
                // This is a placeholder for the actual command execution
                completion(["success": true])
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
    
    @objc func validateAccess(bookmarks: [String: NSData], auditSessionId: au_asid_t, completion: @escaping ([String: Any]?) -> Void) {
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
            logger.error("No XPC connection available",
                        file: #file,
                        function: #function,
                        line: #line)
            throw makeError(.securityValidationFailed)
        }
        
        let pid = connection.processIdentifier
        
        // Create the security requirement
        var requirementRef: SecRequirement?
        let status = SecRequirementCreateWithString(requirement as CFString, [], &requirementRef)
        guard status == errSecSuccess, let requirement = requirementRef else {
            logger.error("Failed to create security requirement",
                        file: #file,
                        function: #function,
                        line: #line)
            throw makeError(.securityValidationFailed)
        }
        
        // Validate the client's code
        guard let codeRef = SecCodeCreateWithAuditToken(pid),
              SecCodeCheckValidityWithErrors(codeRef, [], requirement, nil) == errSecSuccess else {
            logger.error("Client validation failed",
                        file: #file,
                        function: #function,
                        line: #line)
            throw makeError(.securityValidationFailed)
        }
    }
    
    private func validateAuditSession(_ auditSessionId: au_asid_t) throws {
        guard let connection = NSXPCConnection.current(),
              connection.auditSessionIdentifier == auditSessionId else {
            logger.error("Audit session validation failed",
                        file: #file,
                        function: #function,
                        line: #line)
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
        return status == errSecSuccess ? code : nil
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
                  !isStale else {
                throw makeError(.bookmarkValidationFailed)
            }
            
            guard url.startAccessingSecurityScopedResource() else {
                throw makeError(.accessDenied)
            }
            url.stopAccessingSecurityScopedResource()
        }
    }
}

extension ResticService: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
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
