import Core
import Foundation

extension RepositoryListViewModel {
    /// Validates prerequisites before refreshing repository data
    func validateRefreshPrerequisites() async throws {
        // Check storage access
        guard try await hasStorageAccess() else {
            throw RepositoryUIError.accessDenied("Cannot access repository storage")
        }

        // Validate security requirements
        try await validateSecurityRequirements()
    }

    /// Validates that security requirements are met
    private func validateSecurityRequirements() async throws {
        let requirements = try await securityService.validateSecurityRequirements()
        guard requirements.isValid else {
            throw RepositoryUIError.securityRequirementsFailed(requirements.failureReason ?? "Unknown error")
        }
    }

    /// Checks if we have access to repository storage
    private func hasStorageAccess() async throws -> Bool {
        try await securityService.validateStorageAccess()
    }
}
