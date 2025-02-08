//
//  RepositoryListViewModel+State.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation

extension RepositoryListViewModel {
    /// Manages the state of the repository list
    enum State {
        case loading
        case loaded([Repository])
        case error(Error)
        case empty
    }
    
    /// Updates the state of the repository list
    /// - Parameter repositories: The repositories to display
    func updateState(with repositories: [Repository]) {
        if repositories.isEmpty {
            state = .empty
        } else {
            state = .loaded(repositories)
        }
    }
    
    /// Updates the state with an error
    /// - Parameter error: The error to display
    func updateState(with error: Error) {
        state = .error(error)
    }
    
    /// Sets the state to loading
    func setLoading() {
        state = .loading
    }
}
