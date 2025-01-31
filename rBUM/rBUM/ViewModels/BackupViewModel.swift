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
    
    func selectPaths() async {
        await MainActor.run {
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
        }
    }
    
    func startBackup() async {
        guard !selectedPaths.isEmpty else { return }
        
        do {
            // Reset state
            currentStatus = nil
            currentProgress = nil
            
            // Get repository credentials
            guard let credentials = try? credentialsManager.getCredentials(for: repository) else {
                state = .failed(ResticError.credentialsNotFound)
                return
            }
            
            // Create ResticRepository
            let resticRepo = ResticRepository(
                name: repository.name,
                path: repository.path,
                credentials: credentials
            )
            
            // Start backup
            try await resticService.createBackup(
                paths: selectedPaths,
                to: resticRepo,
                tags: nil,
                onProgress: { [weak self] progress in
                    guard let self = self else { return }
                    if case .backing = self.state {
                        // Only update progress if we're already in backing state
                        self.state = .backing(progress)
                    }
                },
                onStatusChange: { [weak self] status in
                    self?.state = status
                }
            )
        } catch {
            state = .failed(error)
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
        case .backing(let progress):
            return "Backing up \(progress.processedFiles)/\(progress.totalFiles) files (\(Int(progress.byteProgress))%)"
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
            return progress.byteProgress
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
        state = .failed(error)
        showError = true
    }
    
    func reset() {
        state = .preparing
        selectedPaths = []
        showError = false
        currentStatus = nil
        currentProgress = nil
    }
}
