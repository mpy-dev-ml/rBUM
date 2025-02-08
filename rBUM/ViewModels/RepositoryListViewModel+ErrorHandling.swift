//
//  RepositoryListViewModel+ErrorHandling.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation

extension RepositoryListViewModel {
    /// Handles an error that occurred during repository operations
    /// - Parameter error: The error to handle
    func handleError(_ error: Error) {
        logger.error("Repository operation failed: \(error.localizedDescription)")
        self.error = error
        self.showError = true
    }
    
    /// Dismisses the current error
    func dismissError() {
        error = nil
        showError = false
    }
    
    /// Handles an error during repository refresh
    /// - Parameter error: The error that occurred
    func handleRefreshError(_ error: Error) {
        logger.error("Repository refresh failed: \(error.localizedDescription)")
        handleError(error)
        state = .error(error)
    }
    
    /// Handles an error during repository validation
    /// - Parameter error: The error that occurred
    func handleValidationError(_ error: Error) {
        logger.error("Repository validation failed: \(error.localizedDescription)")
        handleError(error)
    }
    
    /// Handles an error during repository deletion
    /// - Parameter error: The error that occurred
    func handleDeletionError(_ error: Error) {
        logger.error("Repository deletion failed: \(error.localizedDescription)")
        handleError(error)
    }
}
