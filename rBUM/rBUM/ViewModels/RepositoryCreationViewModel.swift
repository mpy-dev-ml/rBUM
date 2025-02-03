//
//  RepositoryCreationViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import AppKit
import Logging
import Core

/// macOS implementation of repository creation view model
@MainActor
final class RepositoryCreationViewModel: ObservableObject, RepositoryCreationViewModelProtocol {
    // MARK: - Published Properties
    
    @Published var name: String = ""
    @Published var password: String = ""
    @Published private(set) var directoryURL: URL?
    @Published private(set) var directoryBookmark: Data?
    @Published var mode: RepositoryCreationMode = .create
    @Published private(set) var state: RepositoryCreationState = .idle
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private let creationService: RepositoryCreationServiceProtocol
    private let securityService: SecurityService
    private let logger: Logger
    private var resourceAccessToken: ResourceAccessToken?
    
    // MARK: - Initialization
    
    init(
        creationService: RepositoryCreationServiceProtocol = DefaultRepositoryCreationService(),
        securityService: SecurityService = SecurityService(platformService: DefaultSecurityService()),
        logger: Logger = Logger(label: "dev.mpy.rbum.viewmodel.creation")
    ) {
        self.creationService = creationService
        self.securityService = securityService
        self.logger = logger
        
        logger.debug("ViewModel initialised", metadata: [
            "mode": .string(mode.rawValue)
        ])
    }
    
    deinit {
        cleanupSecurityScopedAccess()
    }
    
    // MARK: - Validation
    
    var isValid: Bool {
        guard !name.isEmpty, !password.isEmpty else { return false }
        return directoryBookmark != nil
    }
    
    // MARK: - Directory Selection
    
    func selectDirectory() async {
        logger.debug("Opening directory selection panel", metadata: [
            "mode": .string(mode.rawValue)
        ])
        
        // Clean up any existing security-scoped access
        cleanupSecurityScopedAccess()
        
        let panel = NSOpenPanel()
        panel.title = mode == .create ? "Choose Repository Location" : "Select Repository"
        panel.canChooseFiles = mode == .import
        panel.canChooseDirectories = mode == .create
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = mode == .create
        
        guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
              let url = panel.url else {
            logger.debug("Directory selection cancelled")
            return
        }
        
        do {
            // Create and validate security-scoped bookmark
            let bookmark = try await securityService.createSecurityScopedBookmark(
                for: url,
                readOnly: mode == .import,
                requiredKeys: [.isDirectoryKey]
            )
            
            // Start security-scoped access and get cleanup token
            let (resolvedURL, cleanup) = try await securityService.accessSecurityScopedResource(bookmark)
            
            // Store cleanup token
            resourceAccessToken = ResourceAccessToken(url: resolvedURL, cleanup: cleanup)
            
            // Verify directory type
            let isDirectory = try resolvedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
            if mode == .create && !isDirectory {
                throw RepositoryError.invalidPath
            }
            
            directoryURL = resolvedURL
            directoryBookmark = bookmark
            
            logger.info("Directory selected successfully", metadata: [
                "path": .string(resolvedURL.path),
                "mode": .string(mode.rawValue),
                "isDirectory": .string("\(isDirectory)"),
                "readOnly": .string("\(mode == .import)")
            ])
            
        } catch {
            logger.error("Failed to create bookmark", metadata: [
                "error": .string(error.localizedDescription),
                "path": .string(url.path),
                "mode": .string(mode.rawValue)
            ])
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }
    
    // MARK: - Repository Creation/Import
    
    func createOrImport() async {
        guard isValid else {
            logger.warning("Invalid form state", metadata: [
                "name": .string(name.isEmpty ? "empty" : "valid"),
                "password": .string(password.isEmpty ? "empty" : "valid"),
                "bookmark": .string(directoryBookmark == nil ? "missing" : "present"),
                "mode": .string(mode.rawValue)
            ])
            return
        }
        
        guard let bookmark = directoryBookmark else {
            logger.error("Missing directory bookmark", metadata: [
                "mode": .string(mode.rawValue)
            ])
            state = .error(RepositoryError.invalidPath)
            showError = true
            return
        }
        
        do {
            // Access security-scoped resource
            let (url, cleanup) = try await securityService.accessSecurityScopedResource(bookmark)
            defer { cleanup() }
            
            // Create or import repository
            logger.info("Starting repository operation", metadata: [
                "mode": .string(mode.rawValue),
                "path": .string(url.path)
            ])
            
            state = mode == .create ? .creating : .importing
            let repository = try await mode == .create
                ? creationService.createRepository(name: name, at: url, password: password)
                : creationService.importRepository(name: name, at: url, password: password)
            
            logger.info("Repository operation successful", metadata: [
                "mode": .string(mode.rawValue),
                "id": .string(repository.id),
                "path": .string(repository.path)
            ])
            
            // Store repository credentials securely
            try securityService.storeCredentials(
                password.data(using: .utf8)!,
                identifier: repository.id
            )
            
            state = .idle
            
        } catch {
            logger.error("Repository operation failed", metadata: [
                "mode": .string(mode.rawValue),
                "error": .string(error.localizedDescription)
            ])
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }
    
    // MARK: - Private Methods
    
    private func cleanupSecurityScopedAccess() {
        if let token = resourceAccessToken {
            token.cleanup()
            logger.debug("Cleaned up security-scoped access", metadata: [
                "path": .string(token.url.path)
            ])
            resourceAccessToken = nil
        }
        directoryURL = nil
        directoryBookmark = nil
    }
}

/// Token for managing security-scoped resource access
private struct ResourceAccessToken {
    let url: URL
    let cleanup: () -> Void
}
