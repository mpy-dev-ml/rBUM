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
            try await handleRepositoryCreation()
        } catch {
            logger.error("Repository operation failed: \(error.localizedDescription)")
            state = .error(error)
            showError = true
            cleanupSecurityScopedAccess()
        }
    }

    private func handleRepositoryCreation() async throws {
        try await validateRepositoryInput()
        try await createRepository()
        try await handleRepositoryCreationCompletion()
    }

    private func validateRepositoryInput() async throws {
        // Validate name
        try validateRepositoryName()

        // Validate location
        try validateRepositoryLocation()

        // Validate credentials
        try validateRepositoryCredentials()

        // Validate permissions
        try await validateRepositoryPermissions()
    }

    private func validateRepositoryName() throws {
        guard !name.isEmpty else {
            throw RepositoryError.invalidName("Repository name cannot be empty")
        }

        guard name.count <= 255 else {
            throw RepositoryError.invalidName("Repository name is too long")
        }

        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?*|\"<>")
        guard name.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw RepositoryError.invalidName("Repository name contains invalid characters")
        }
    }

    private func validateRepositoryLocation() throws {
        guard let location = directoryURL else {
            throw RepositoryError.invalidLocation("Repository location is not selected")
        }

        guard location.isFileURL else {
            throw RepositoryError.invalidLocation("Repository location must be a local directory")
        }
    }

    private func validateRepositoryCredentials() throws {
        guard !password.isEmpty else {
            throw RepositoryError.invalidCredentials("Repository password cannot be empty")
        }

        // Check password strength
        try validatePasswordStrength(password)
    }

    private func validatePasswordStrength(_ password: String) throws {
        // Check length
        guard password.count >= 12 else {
            throw RepositoryError.weakPassword("Password must be at least 12 characters long")
        }

        // Check complexity
        let hasUppercase = password.contains(where: \.isUppercase)
        let hasLowercase = password.contains(where: \.isLowercase)
        let hasNumbers = password.contains(where: \.isNumber)
        let hasSpecialCharacters = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })

        guard hasUppercase, hasLowercase, hasNumbers, hasSpecialCharacters else {
            throw RepositoryError.weakPassword(
                "Password must contain uppercase, lowercase, numbers, and special characters"
            )
        }
    }

    private func validateRepositoryPermissions() async throws {
        guard let location = directoryURL else { return }

        // Check directory access
        guard try await securityService.validateAccess(to: location) else {
            throw RepositoryError.accessDenied("Cannot access repository location")
        }

        // Check write permissions
        guard try await securityService.validateWriteAccess(to: location) else {
            throw RepositoryError.accessDenied("Cannot write to repository location")
        }
    }

    private func createRepository() async throws {
        guard let location = directoryURL else { return }

        state = mode == .create ? .creating : .importing

        do {
            // Create or import repository
            logger.info("Starting repository operation")

            let repository = try await mode == .create
                ? creationService.createRepository(name: name, at: location, password: password)
                : creationService.importRepository(name: name, at: location, password: password)

            logger.info("Repository operation successful")

            // Store repository credentials securely
            try await securityService.storeCredentials(
                password.data(using: .utf8)!,
                identifier: repository.id
            )

            state = .idle

        } catch {
            throw error
        }
    }

    private func handleRepositoryCreationCompletion() async throws {
        Task { @MainActor in
            state = .idle

            // Log completion
            logger.info("Repository created successfully", metadata: [
                "name": .string(name),
                "location": .string(directoryURL?.path ?? "unknown"),
            ])

            // Clear sensitive data
            password = ""
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
