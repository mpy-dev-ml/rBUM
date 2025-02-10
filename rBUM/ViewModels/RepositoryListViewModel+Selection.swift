import Core
import Foundation

extension RepositoryListViewModel {
    /// Handles selection of a repository
    /// - Parameter repository: The repository to select
    func selectRepository(_ repository: Repository) {
        selectedRepository = repository
    }

    /// Deselects the currently selected repository
    func deselectRepository() {
        selectedRepository = nil
    }

    /// Checks if a repository is currently selected
    /// - Parameter repository: The repository to check
    /// - Returns: True if the repository is selected
    func isSelected(_ repository: Repository) -> Bool {
        selectedRepository?.id == repository.id
    }

    /// Updates the selection after a repository is deleted
    /// - Parameter repository: The deleted repository
    func handleRepositoryDeletion(_ repository: Repository) {
        if isSelected(repository) {
            deselectRepository()
        }
    }
}
