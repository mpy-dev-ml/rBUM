import Foundation

extension SnapshotListViewModel {
    // MARK: - Repository Access Validation

    /// Validate access to the repository
    /// - Parameter repository: The repository to validate
    func validateRepositoryAccess(_ repository: Repository) async throws {
        guard let url = repository.url else {
            throw SnapshotError.invalidRepository("Repository URL is missing")
        }

        // Validate security access
        try await securityService.validateAccess(to: url)

        // Load credentials
        guard let credentials = try await credentialsService.loadCredentials(for: repository) else {
            throw SnapshotError.accessDenied("Repository credentials not found")
        }

        // Validate repository connection
        try await repositoryService.validateAccess(
            to: repository,
            with: credentials
        )
    }

    /// Validate access to a destination URL
    /// - Parameter url: The URL to validate
    func validateDestinationAccess(_ url: URL) async throws {
        try await securityService.validateAccess(to: url)
    }
}
