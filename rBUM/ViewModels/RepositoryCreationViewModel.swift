//
//  RepositoryCreationViewModel.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import AppKit
import Core
import Foundation
import os.log

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
    private let securityService: SecurityServiceProtocol
    private let logger: Logger
    private var resourceAccessToken: ResourceAccessToken?

    // MARK: - Initialization

    init(
        creationService: RepositoryCreationServiceProtocol,
        securityService: SecurityServiceProtocol,
        logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "repository-creation")
    ) {
        self.creationService = creationService
        self.securityService = securityService
        self.logger = logger

        logger.debug("ViewModel initialised")
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
        logger.debug("Opening directory selection panel")

        // Clean up any existing security-scoped access
        cleanupSecurityScopedAccess()

        let panel = NSOpenPanel()
        panel.title = mode == .create ? "Choose Repository Location" : "Select Repository"
        panel.canChooseFiles = mode == .import
        panel.canChooseDirectories = mode == .create
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = mode == .create

        guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK,
              let url = panel.url
        else {
            logger.debug("Directory selection cancelled")
            return
        }

        do {
            // Create and validate security-scoped bookmark
            let bookmark = try await securityService.createBookmark(
                for: url,
                readOnly: mode == .import
            )

            // Start security-scoped access and get cleanup token
            let (resolvedURL, cleanup) = try await securityService.validateAccess(to: url)

            // Store cleanup token
            resourceAccessToken = ResourceAccessToken(url: resolvedURL, cleanup: cleanup)

            // Verify directory type
            let isDirectory = try resolvedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
            if mode == .create, !isDirectory {
                throw RepositoryError.invalidPath
            }

            directoryURL = resolvedURL
            directoryBookmark = bookmark

            logger.info("Directory selected successfully")

        } catch {
            logger.error("Failed to create bookmark: \(error.localizedDescription)")
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }

    // MARK: - Repository Creation/Import

    func createOrImport() async {
        guard isValid else {
            logger.warning("Invalid form state")
            return
        }

        guard let bookmark = directoryBookmark else {
            logger.error("Missing directory bookmark")
            state = .error(RepositoryError.invalidPath)
            showError = true
            return
        }

        do {
            // Access security-scoped resource
            let (url, cleanup) = try await securityService.validateAccess(to: url)
            defer { cleanup() }

            // Create or import repository
            logger.info("Starting repository operation")

            state = mode == .create ? .creating : .importing
            let repository = try await mode == .create
                ? creationService.createRepository(name: name, at: url, password: password)
                : creationService.importRepository(name: name, at: url, password: password)

            logger.info("Repository operation successful")

            // Store repository credentials securely
            try await securityService.storeCredentials(
                password.data(using: .utf8)!,
                identifier: repository.id
            )

            state = .idle

        } catch {
            logger.error("Repository operation failed: \(error.localizedDescription)")
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }

    // MARK: - Private Methods

    private func cleanupSecurityScopedAccess() {
        if let token = resourceAccessToken {
            token.cleanup()
            logger.debug("Cleaned up security-scoped access")
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
