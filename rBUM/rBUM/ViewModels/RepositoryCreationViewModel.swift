//
//  RepositoryCreationViewModel.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
import SwiftUI

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
    @Published var showFilePicker = false
    @Published var showError = false
    
    private let creationService: RepositoryCreationServiceProtocol
    private let logger = Logging.logger(for: .repository)
    
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
    
    init(creationService: RepositoryCreationServiceProtocol) {
        self.creationService = creationService
    }
    
    func createOrImport() async {
        guard isValid else { return }
        
        state = .creating
        
        do {
            let repository: Repository
            let url = URL(filePath: path)
            
            switch mode {
            case .create:
                repository = try await creationService.createRepository(
                    name: name,
                    path: url,
                    password: password
                )
                logger.infoMessage("Created repository: \(repository.id) at \(path)")
                
            case .import:
                repository = try await creationService.importRepository(
                    name: name,
                    path: url,
                    password: password
                )
                logger.infoMessage("Imported repository: \(repository.id) from \(path)")
            }
            
            state = .success(repository)
        } catch {
            logger.errorMessage("Failed to \(mode == .create ? "create" : "import") repository: \(error.localizedDescription)")
            state = .error(error)
            showError = true
        }
    }
    
    func selectPath() {
        showFilePicker = true
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
