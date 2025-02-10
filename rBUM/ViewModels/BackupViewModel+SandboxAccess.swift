import Core
import Foundation

extension BackupViewModel {
    // MARK: - Sandbox Access Management

    /// Validate and ensure access to backup source locations
    /// - Throws: SandboxError if access cannot be obtained
    func validateSourceAccess() async throws {
        guard let sources = configuration.sources else {
            throw SandboxError.accessDenied("No backup sources configured")
        }

        for source in sources {
            try await validateAccess(to: source)
        }
    }

    /// Validate and ensure access to repository location
    /// - Throws: SandboxError if access cannot be obtained
    func validateRepositoryAccess() async throws {
        guard let repository = configuration.repository,
              let url = repository.url
        else {
            throw SandboxError.accessDenied("No repository configured")
        }

        try await validateAccess(to: url)
    }

    /// Validate access to a specific URL
    /// - Parameter url: URL to validate access for
    /// - Throws: SandboxError if access cannot be obtained
    private func validateAccess(to url: URL) async throws {
        do {
            // First try to validate existing access
            if try await securityService.validateAccess(to: url) {
                logger.debug("Access validated for \(url.lastPathComponent)", privacy: .public)
                return
            }

            // If validation fails, try to restore from bookmark
            if let bookmark = try await bookmarkService.getBookmark(for: url) {
                try await bookmarkService.startAccessing(url, with: bookmark)
                logger.debug("Access restored from bookmark for \(url.lastPathComponent)", privacy: .public)
                return
            }

            // If no bookmark exists, request new access
            try await requestNewAccess(to: url)

        } catch {
            logger.error("Failed to validate access: \(error.localizedDescription)", privacy: .public)
            throw SandboxError.accessDenied("Could not access \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Request new access to a URL and persist it
    /// - Parameter url: URL to request access for
    /// - Throws: SandboxError if access cannot be obtained
    private func requestNewAccess(to url: URL) async throws {
        do {
            // Request user permission
            let granted = try await securityService.requestAccess(to: url)
            guard granted else {
                throw SandboxError.accessDenied("Access denied by user")
            }

            // Create and store bookmark
            let bookmark = try await bookmarkService.createBookmark(for: url)
            try await bookmarkService.startAccessing(url, with: bookmark)

            logger.debug("New access granted and persisted for \(url.lastPathComponent)", privacy: .public)

        } catch {
            logger.error("Failed to request access: \(error.localizedDescription)", privacy: .public)
            throw SandboxError.accessDenied("Could not obtain access to \(url.lastPathComponent)")
        }
    }

    /// Clean up access to all resources
    func cleanupAccess() {
        Task {
            do {
                // Clean up source access
                if let sources = configuration.sources {
                    for source in sources {
                        try? await bookmarkService.stopAccessing(source)
                    }
                }

                // Clean up repository access
                if let repository = configuration.repository?.url {
                    try? await bookmarkService.stopAccessing(repository)
                }

                logger.debug("Cleaned up all resource access", privacy: .public)
            } catch {
                logger.error("Error during access cleanup: \(error.localizedDescription)", privacy: .public)
            }
        }
    }
}
