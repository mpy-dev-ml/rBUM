//
//  BackupViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI

@MainActor
final class BackupViewModel: ObservableObject {
    enum BackupState {
        case idle
        case selecting
        case inProgress(BackupProgress)
        case completed
        case failed(Error)
    }
    
    @Published private(set) var state: BackupState = .idle
    @Published var selectedPaths: [URL] = []
    @Published var showError = false
    @Published private(set) var currentStatus: BackupStatus?
    @Published private(set) var currentProgress: BackupProgress?
    
    private let repository: Repository
    private let resticService: ResticCommandServiceProtocol
    private let credentialsManager: CredentialsManagerProtocol
    private let logger = Logging.logger(for: .backup)
    
    init(
        repository: Repository,
        resticService: ResticCommandServiceProtocol,
        credentialsManager: CredentialsManagerProtocol
    ) {
        self.repository = repository
        self.resticService = resticService
        self.credentialsManager = credentialsManager
    }
    
    func selectPaths() {
        state = .selecting
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.message = "Select files and folders to back up"
        panel.prompt = "Back Up"
        
        if panel.runModal() == .OK {
            selectedPaths = panel.urls
            logger.infoMessage("Selected \(selectedPaths.count) paths for backup")
        }
        
        state = .idle
    }
    
    func startBackup() async {
        guard !selectedPaths.isEmpty else { return }
        
        do {
            // Reset state
            currentStatus = nil
            currentProgress = nil
            state = .idle
            
            // Create credentials for backup
            let password = try await credentialsManager.getPassword(forRepositoryId: repository.id)
            let credentials = RepositoryCredentials(
                repositoryId: repository.id,
                password: password,
                repositoryPath: repository.path.path
            )
            
            // Start backup with progress reporting
            try await resticService.createBackup(
                paths: selectedPaths,
                to: repository,
                credentials: credentials,
                tags: nil,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.currentProgress = progress
                        self?.state = .inProgress(progress)
                    }
                },
                onStatusChange: { [weak self] status in
                    Task { @MainActor in
                        self?.currentStatus = status
                        if case .completed = status {
                            self?.handleBackupCompleted()
                        } else if case .failed(let error) = status {
                            self?.handleBackupFailed(error)
                        }
                    }
                }
            )
        } catch {
            handleBackupFailed(error)
        }
    }
    
    private func handleBackupCompleted() {
        state = .completed
        logger.infoMessage("Backup completed successfully")
        
        // Reset for next backup after delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            reset()
        }
    }
    
    private func handleBackupFailed(_ error: Error) {
        logger.errorMessage("Backup failed: \(error.localizedDescription)")
        state = .failed(error)
        showError = true
    }
    
    func reset() {
        state = .idle
        selectedPaths = []
        showError = false
        currentStatus = nil
        currentProgress = nil
    }
    
    // MARK: - Progress Formatting
    
    var progressMessage: String {
        switch state {
        case .idle:
            return "Ready to start backup"
        case .selecting:
            return "Selecting files..."
        case .inProgress(let progress):
            return "Backing up: \(progress.formattedProgress())"
        case .completed:
            return "Backup completed successfully"
        case .failed(let error):
            return "Backup failed: \(error.localizedDescription)"
        }
    }
    
    var progressPercentage: Double {
        switch state {
        case .inProgress(let progress):
            return progress.overallProgress
        case .completed:
            return 100
        default:
            return 0
        }
    }
}
