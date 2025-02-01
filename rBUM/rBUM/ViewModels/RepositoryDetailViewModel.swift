//
//  RepositoryDetailViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI

@MainActor
final class RepositoryDetailViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case snapshots = "Snapshots"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .overview:
                return "info.circle"
            case .snapshots:
                return "clock"
            case .settings:
                return "gear"
            }
        }
    }
    
    @Published var selectedTab: Tab = .overview
    @Published private(set) var repository: Repository
    @Published private(set) var lastCheck: Date?
    @Published private(set) var isChecking: Bool = false
    @Published var error: Error?
    @Published var showError: Bool = false
    @Published private(set) var repositoryStatus: RepositoryStatus?
    
    private let resticService: ResticCommandServiceProtocol
    private let credentialsManager: CredentialsManagerProtocol
    private let logger = Logging.logger(for: .repository)
    
    init(
        repository: Repository,
        resticService: ResticCommandServiceProtocol = ResticCommandService(
            fileManager: .default,
            logger: Logging.logger(for: .repository)
        ),
        credentialsManager: CredentialsManagerProtocol = KeychainCredentialsManager()
    ) {
        self.repository = repository
        self.resticService = resticService
        self.credentialsManager = credentialsManager
    }
    
    func checkRepository() async {
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        
        do {
            // Get repository password
            let password = try await credentialsManager.getPassword(forRepositoryId: repository.id)
            
            // Create Repository with credentials
            let credentials = RepositoryCredentials(
                repositoryId: repository.id,
                password: password,
                repositoryPath: repository.path.path
            )
            
            let repoWithCredentials = Repository(
                name: repository.name,
                path: repository.path,
                credentials: credentials
            )
            
            // Check repository
            try await resticService.check(repoWithCredentials)
            
            // Update last check time
            lastCheck = Date()
            logger.infoMessage("Repository check successful: \(repository.id)")
        } catch {
            self.error = error
            self.showError = true
            logger.errorMessage("Repository check failed: \(error.localizedDescription)")
        }
    }
    
    func updatePassword(_ newPassword: String) async throws {
        guard !newPassword.isEmpty else {
            throw ResticError.invalidPassword
        }
        
        let credentials = RepositoryCredentials(
            repositoryId: repository.id,
            password: newPassword,
            repositoryPath: repository.path.path
        )
        
        try await credentialsManager.store(credentials)
        logger.infoMessage("Updated password for repository: \(repository.id)")
    }
    
    var formattedLastCheck: String {
        guard let lastCheck else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastCheck, relativeTo: Date())
    }
    
    var statusColor: Color {
        guard let lastCheck else {
            return .secondary
        }
        
        // If checked in last hour and no error, show green
        if Date().timeIntervalSince(lastCheck) < 3600 && error == nil {
            return .green
        }
        
        // If error or not checked in last day, show red
        if error != nil || Date().timeIntervalSince(lastCheck) > 86400 {
            return .red
        }
        
        // Otherwise show yellow
        return .yellow
    }
}
