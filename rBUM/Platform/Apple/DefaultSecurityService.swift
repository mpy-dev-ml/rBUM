//
//  DefaultSecurityService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import Core
import Security
import AppKit

/// macOS-specific implementation of security service
public class DefaultSecurityService: BaseSandboxedService, Measurable {
    // MARK: - Properties
    private let bookmarkService: BookmarkServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let sandboxMonitor: SandboxMonitorProtocol
    private let operationQueue: OperationQueue
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.defaultSecurity", attributes: .concurrent)
    private var activeOperations: Set<UUID> = []

    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            self.activeOperations.isEmpty
        }
    }

    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        keychainService: KeychainServiceProtocol,
        sandboxMonitor: SandboxMonitorProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService
        self.sandboxMonitor = sandboxMonitor

        self.operationQueue = OperationQueue()
        self.operationQueue.name = "dev.mpy.rBUM.defaultSecurityQueue"
        self.operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - SecurityServiceProtocol Implementation
    public func requestPermission(for url: URL) async throws -> Bool {
        try await measure("Request Permission") {
            // First check if we already have access
            if try await validateAccess(to: url) {
                return true
            }

            // Show open panel to request access
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = url
            panel.message = "Please grant access to this location"
            panel.prompt = "Grant Access"

            let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
            return response == .OK
        }
    }

    public func createBookmark(for url: URL) throws -> Data {
        try bookmarkService.createBookmark(for: url)
    }

    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try bookmarkService.resolveBookmark(bookmark)
    }

    public func validateAccess(to url: URL) async throws -> Bool {
        try await measure("Validate Access") {
            do {
                let bookmark = try bookmarkService.createBookmark(for: url)
                return try bookmarkService.validateBookmark(bookmark)
            } catch {
                logger.error("Failed to validate access: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
                return false
            }
        }
    }

    public override func startAccessing(_ url: URL) -> Bool {
        do {
            return try bookmarkService.startAccessing(url)
        } catch {
            logger.error("Failed to start accessing: \(error.localizedDescription)",
                       file: #file,
                       function: #function,
                       line: #line)
            return false
        }
    }

    public override func stopAccessing(_ url: URL) {
        Task {
            do {
                try await bookmarkService.stopAccessing(url)
            } catch {
                logger.error("Failed to stop accessing: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
            }
        }
    }

    public func persistAccess(to url: URL) async throws -> Data {
        try await measure("Persist Access") {
            let bookmark = try bookmarkService.createBookmark(for: url)
            _ = try await sandboxMonitor.startMonitoring(url: url)
            return bookmark
        }
    }

    public func revokeAccess(to url: URL) async throws {
        try await measure("Revoke Access") {
            try await sandboxMonitor.stopMonitoring(for: url)
        }
    }

    // MARK: - HealthCheckable Implementation
    public func performHealthCheck() async -> Bool {
        await measure("Security Health Check") {
            do {
                // Check sandbox monitor
                let monitorHealthy = sandboxMonitor.isHealthy

                // Check active operations
                let operationsHealthy = isHealthy

                return monitorHealthy && operationsHealthy
            } catch {
                logger.error("Health check failed: \(error.localizedDescription)",
                           file: #file,
                           function: #function,
                           line: #line)
                return false
            }
        }
    }

    // MARK: - Private Helpers
    private func trackOperation(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.insert(id)
        }
    }

    private func untrackOperation(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
    }
}
