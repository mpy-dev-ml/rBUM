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
        case backing(progress: Double)
        case completed
        case failed(Error)
    }
    
    @Published private(set) var state: BackupState = .idle
    @Published var selectedPaths: [URL] = []
    @Published var showError = false
    
    private let repository: Repository
    private let resticService: ResticCommandServiceProtocol
    private let logger = Logging.logger(for: .backup)
    
    init(repository: Repository, resticService: ResticCommandServiceProtocol) {
        self.repository = repository
        self.resticService = resticService
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
            state = .backing(progress: 0)
            try await resticService.createBackup(for: repository, paths: selectedPaths.map(\.path))
            state = .completed
            logger.infoMessage("Backup completed successfully")
            
            // Reset for next backup
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.state = .idle
                self.selectedPaths = []
            }
        } catch {
            logger.errorMessage("Backup failed: \(error.localizedDescription)")
            state = .failed(error)
            showError = true
        }
    }
    
    func reset() {
        state = .idle
        selectedPaths = []
        showError = false
    }
}
