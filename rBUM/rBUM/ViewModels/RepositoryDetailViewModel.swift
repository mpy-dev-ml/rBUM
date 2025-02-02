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
    private let credentialsManager: KeychainCredentialsManagerProtocol
    private let logger = Logging.logger(for: .repository)
    
    init(
        repository: Repository,
        resticService: ResticCommandServiceProtocol = ResticCommandService(),
        credentialsManager: KeychainCredentialsManagerProtocol = KeychainCredentialsManager()
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
            // Get repository credentials
            let credentials = try await credentialsManager.retrieve(forId: repository.id)
            
            // Create Repository with credentials
            let repoWithCredentials = Repository(
                id: repository.id,
                name: repository.name,
                path: repository.path,
                createdAt: repository.createdAt,
                credentials: credentials
            )
            
            // List snapshots to verify repository access
            _ = try await resticService.listSnapshots(in: repoWithCredentials)
            lastCheck = Date()
            
            logger.info("Repository check completed successfully: \(self.repository.id, privacy: .public)")
        } catch {
            self.error = error
            showError = true
            logger.error("Repository check failed: \(error.localizedDescription)")
        }
    }
    
    func updateRepositoryPassword(_ newPassword: String) async throws {
        guard !newPassword.isEmpty else {
            throw ResticError.invalidPassword
        }
        
        // Create new credentials with updated password
        let credentials = RepositoryCredentials(
            repositoryPath: self.repository.path,
            password: newPassword
        )
        
        // Store updated credentials
        try await self.credentialsManager.store(credentials, forRepositoryId: self.repository.id)
        self.logger.info("Updated password for repository: \(self.repository.id, privacy: .public)")
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
