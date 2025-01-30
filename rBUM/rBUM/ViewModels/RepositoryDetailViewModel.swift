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
    @Published var repository: Repository
    @Published var lastCheck: Date?
    @Published var error: Error?
    @Published var showError = false
    @Published var isChecking = false
    
    private let resticService: ResticCommandServiceProtocol
    private let logger = Logging.logger(for: .repository)
    
    init(repository: Repository, resticService: ResticCommandServiceProtocol) {
        self.repository = repository
        self.resticService = resticService
    }
    
    func checkRepository() async {
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        
        do {
            let isValid = try await resticService.checkRepository(repository)
            if isValid {
                lastCheck = Date()
                logger.infoMessage("Repository check successful: \(repository.id)")
            } else {
                throw RepositoryCreationError.invalidRepository
            }
        } catch {
            logger.errorMessage("Repository check failed: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
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
