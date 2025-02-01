//
//  RepositoryCreationViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI
import os

@MainActor
final class RepositoryCreationViewModel: ObservableObject {
    enum Mode {
        case create
        case `import`
    }
    
    enum CreationState: Equatable {
        case idle
        case creating
        case success(Repository)
        case error(Error)
        
        static func == (lhs: CreationState, rhs: CreationState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle):
                return true
            case (.creating, .creating):
                return true
            case (.success(let lhsRepo), .success(let rhsRepo)):
                return lhsRepo.id == rhsRepo.id
            case (.error(let lhsError as NSError), .error(let rhsError as NSError)):
                return lhsError.domain == rhsError.domain && lhsError.code == rhsError.code
            default:
                return false
            }
        }
    }
    
    @Published var mode: Mode = .create
    @Published var name: String = ""
    @Published var path: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var state: CreationState = .idle
    @Published var showError = false
    @Published var showSuccess = false
    @Published var createdRepository: Repository?
    
    private let creationService: RepositoryCreationServiceProtocol
    private let credentialsStorage: CredentialsStorageProtocol
    private let logger = Logging.logger(for: .repository)
    private var directoryBookmark: Data?
    private var selectedDirectoryURL: URL?
    
    var errorMessage: String {
        if case .error(let error) = state {
            return error.localizedDescription
        }
        return ""
    }
    
    var isValid: Bool {
        !name.isEmpty && !path.isEmpty && !password.isEmpty && 
        (mode == .import || password == confirmPassword)
    }
    
    init(creationService: RepositoryCreationServiceProtocol, credentialsStorage: CredentialsStorageProtocol) {
        self.creationService = creationService
        self.credentialsStorage = credentialsStorage
    }
    
    func selectPath() {
        let openPanel = NSOpenPanel()
        openPanel.title = mode == .create ? "Choose Repository Location" : "Select Repository"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseFiles = mode == .import
        openPanel.canChooseDirectories = mode == .create
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = openPanel.url {
                Task { @MainActor in
                    do {
                        // Create security-scoped bookmark
                        let bookmark = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        
                        self.directoryBookmark = bookmark
                        self.selectedDirectoryURL = url
                        self.path = url.path
                        
                        // If creating new repository, use the last path component as default name
                        if self.mode == .create && self.name.isEmpty {
                            self.name = url.lastPathComponent
                        }
                        
                        self.logger.infoMessage("Selected path: \(url.path)")
                    } catch {
                        self.logger.errorMessage("Failed to create bookmark: \(error.localizedDescription)")
                        self.state = .error(error)
                        self.showError = true
                    }
                }
            }
        }
    }
    
    func createOrImport() async {
        guard isValid else { return }
        guard let bookmark = directoryBookmark else {
            state = .error(RepositoryCreationError.invalidPath("No directory access granted"))
            showError = true
            return
        }
        
        state = .creating
        
        do {
            var isStale = false
            let baseURL = try URL(resolvingBookmarkData: bookmark,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale)
            
            guard baseURL.startAccessingSecurityScopedResource() else {
                throw RepositoryCreationError.invalidPath("Failed to access directory")
            }
            
            defer { baseURL.stopAccessingSecurityScopedResource() }
            
            let repository: Repository
            let repositoryURL: URL
            
            if mode == .create {
                // For new repositories, append the repository name to the selected directory
                repositoryURL = baseURL.appendingPathComponent(name)
            } else {
                // For imports, use the selected path directly
                repositoryURL = baseURL
            }
            
            switch mode {
            case .create:
                repository = try await creationService.createRepository(
                    name: name,
                    path: repositoryURL,
                    password: password
                )
                self.logger.infoMessage("Created repository: \(repository.id) at \(repositoryURL.path)")
                
            case .import:
                repository = try await creationService.importRepository(
                    name: name,
                    path: repositoryURL,
                    password: password
                )
                self.logger.infoMessage("Imported repository: \(repository.id) from \(repositoryURL.path)")
            }
            
            // Store credentials
            try credentialsStorage.store(
                RepositoryCredentials(repositoryPath: repositoryURL.path, password: password),
                forRepositoryId: repository.id
            )
            
            state = .success(repository)
            createdRepository = repository
            showSuccess = true
            
            // Clear form
            name = ""
            path = ""
            password = ""
            confirmPassword = ""
            
            logger.info("Repository \(mode == .create ? "created" : "imported") successfully: \(repository.id, privacy: .public)")
        } catch {
            self.logger.errorMessage("Failed to \(mode == .create ? "create" : "import") repository: \(error.localizedDescription)")
            state = .error(error)
            showError = true
        }
    }
    
    func reset() {
        name = ""
        path = ""
        password = ""
        confirmPassword = ""
        state = .idle
        showError = false
    }
}
