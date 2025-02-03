//
//  RepositoryCreationViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import AppKit
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
    private let logger: LoggerProtocol
    private var resourceAccessToken: ResourceAccessToken?
    
    // MARK: - Initialization
    
    init(
        creationService: RepositoryCreationServiceProtocol = DefaultRepositoryCreationService(),
        securityService: SecurityService = SecurityService(platformService: DefaultSecurityService()),
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "RepositoryCreation")
    ) {
        self.creationService = creationService
        self.securityService = securityService
        self.logger = logger
        
        logger.debug("ViewModel initialised", privacy: .public)
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
        logger.debug("Opening directory selection panel", privacy: .public)
        
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
            logger.debug("Directory selection cancelled", privacy: .public)
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
            
            logger.info("Directory selected successfully", privacy: .public)
            
        } catch {
            logger.error("Failed to create bookmark", error: error, privacy: .public)
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }
    
    // MARK: - Repository Creation/Import
    
    func createOrImport() async {
        guard isValid else {
            logger.warning("Invalid form state", privacy: .public)
            return
        }
        
        guard let bookmark = directoryBookmark else {
            logger.error("Missing directory bookmark", privacy: .public)
            state = .error(RepositoryError.invalidPath)
            showError = true
            return
        }
        
        do {
            // Access security-scoped resource
            let (url, cleanup) = try await securityService.accessSecurityScopedResource(bookmark)
            defer { cleanup() }
            
            // Create or import repository
            logger.info("Starting repository operation", privacy: .public)
            
            state = mode == .create ? .creating : .importing
            let repository = try await mode == .create
                ? creationService.createRepository(name: name, at: url, password: password)
                : creationService.importRepository(name: name, at: url, password: password)
            
            logger.info("Repository operation successful", privacy: .public)
            
            // Store repository credentials securely
            try securityService.storeCredentials(
                password.data(using: .utf8)!,
                identifier: repository.id
            )
            
            state = .idle
            
        } catch {
            logger.error("Repository operation failed", error: error, privacy: .public)
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }
    
    // MARK: - Private Methods
    
    private func cleanupSecurityScopedAccess() {
        if let token = resourceAccessToken {
            token.cleanup()
            logger.debug("Cleaned up security-scoped access", privacy: .public)
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
