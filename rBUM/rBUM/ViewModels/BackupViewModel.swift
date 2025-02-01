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
    @Published private(set) var state: ResticBackupStatus = .preparing
    @Published var selectedPaths: [URL] = []
    @Published var showError = false
    @Published private(set) var currentProgress: ResticBackupProgress?
    
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
    
    func selectPaths() async {
        await MainActor.run { @MainActor in
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            panel.canCreateDirectories = false
            panel.message = "Select files and folders to back up"
            panel.prompt = "Back Up"
            
            Task {
                guard await panel.beginSheetModal(for: NSApp.keyWindow!) == .OK else {
                    return
                }
                
                selectedPaths = panel.urls
                logger.infoMessage("Selected \(selectedPaths.count) paths for backup")
            }
        }
    }
    
    func startBackup() async {
        guard !selectedPaths.isEmpty else {
            logger.infoMessage("No paths selected for backup")
            return
        }
        
        do {
            // Reset state
            currentProgress = nil
            
            // Get repository credentials
            let password = try await credentialsManager.getPassword(forRepositoryId: repository.id)
            
            // Create ResticRepository with credentials
            let credentials = RepositoryCredentials(
                repositoryId: repository.id,
                password: password,
                repositoryPath: repository.path.path
            )
            
            let resticRepo = ResticRepository(
                name: repository.name,
                path: repository.path,
                credentials: credentials
            )
            
            // Start backup
            try await resticService.createBackup(
                paths: selectedPaths,
                to: resticRepo,
                tags: nil,  // No tags for now, can be added as a feature later
                onProgress: { [weak self] progress in
                    self?.currentProgress = progress
                },
                onStatusChange: { [weak self] status in
                    self?.state = status
                }
            )
            
            logger.infoMessage("Backup completed successfully")
        } catch {
            logger.errorMessage("Backup failed: \(error.localizedDescription)")
            if let backupError = error as? ResticBackupError {
                state = .failed(backupError)
            } else {
                state = .failed(ResticBackupError(
                    type: .unclassifiedError,
                    message: error.localizedDescription
                ))
            }
            showError = true
        }
    }
    
    func cancelBackup() async {
        state = .cancelled
    }
    
    var progressMessage: String {
        switch state {
        case .preparing:
            return "Preparing backup..."
        case .backing:
            return "Backing up..."
        case .finalising:
            return "Finalizing backup..."
        case .completed:
            return "Backup completed"
        case .failed(let error):
            return "Backup failed: \(error.localizedDescription)"
        case .cancelled:
            return "Backup cancelled"
        }
    }
    
    var progressPercentage: Double {
        switch state {
        case .backing(let progress):
            return progress.percentComplete
        case .completed:
            return 100
        default:
            return 0
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
        state = .failed(error as! ResticBackupError)
        showError = true
    }
    
    func reset() {
        state = .preparing
        selectedPaths = []
        showError = false
        currentProgress = nil
    }
}
