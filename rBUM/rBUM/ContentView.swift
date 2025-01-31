//
//  ContentView.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    
    init(credentialsManager: CredentialsManagerProtocol) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(credentialsManager: credentialsManager))
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $viewModel.selectedSidebarItem)
        } detail: {
            switch viewModel.selectedSidebarItem {
            case .repositories:
                RepositoryListView()
            case .backups:
                Text("Backup List")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .schedules:
                Text("Schedule List")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .none:
                EmptyView()
            }
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case repositories = "Repositories"
    case backups = "Backups"
    case schedules = "Schedules"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .repositories:
            return "folder"
        case .backups:
            return "arrow.clockwise"
        case .schedules:
            return "calendar"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
        }
        .navigationTitle("rBUM")
    }
}

#Preview {
    ContentView(
        credentialsManager: KeychainCredentialsManager(
            keychainService: MockKeychainService(),
            credentialsStorage: MockCredentialsStorage()
        )
    )
}

// MARK: - Preview Helpers

private final class PreviewRepositoryStorage: RepositoryStorageProtocol {
    func store(_ repository: Repository) throws {}
    func retrieve(forId id: UUID) throws -> Repository? { nil }
    func list() throws -> [Repository] { [] }
    func delete(forId id: UUID) throws {}
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool { false }
}

private final class PreviewRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        Repository(name: name, path: path)
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        Repository(name: name, path: path)
    }
}

private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    func checkRepository(_ repository: URL, withPassword password: String) async throws -> RepositoryStatus {
        // Return mock status for preview
        return RepositoryStatus(
            isValid: true,
            packsValid: true,
            indexValid: true,
            snapshotsValid: true,
            errors: [],
            stats: .init(
                totalSize: 1024 * 1024 * 100,  // 100 MB
                packFiles: 10,
                snapshots: 5
            )
        )
    }
    
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws {}
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
        credentials: RepositoryCredentials,
        tags: [String]?,
        onProgress: ((BackupProgress) -> Void)?,
        onStatusChange: ((BackupStatus) -> Void)?
    ) async throws {
        // Simulate backup progress
        onStatusChange?(.preparing)
        
        // Simulate progress updates
        let progress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024,
            currentFile: "/test/file.txt",
            estimatedSecondsRemaining: 30,
            startTime: Date()
        )
        onProgress?(progress)
        onStatusChange?(.backing(progress))
        
        // Simulate completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
        onStatusChange?(.completed)
    }
    
    func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot] {
        []
    }
    
    func pruneSnapshots(
        in repository: Repository,
        credentials: RepositoryCredentials,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {
        // No changes made here
    }
}

class ContentViewModel: ObservableObject {
    @Published var selectedSidebarItem: SidebarItem? = .repositories
    
    let repositoryStorage: RepositoryStorageProtocol
    let repositoryCreationService: RepositoryCreationServiceProtocol
    let resticService: ResticCommandServiceProtocol
    let credentialsManager: CredentialsManagerProtocol
    
    init(credentialsManager: CredentialsManagerProtocol) {
        self.credentialsManager = credentialsManager
        self.repositoryStorage = RepositoryStorage()
        self.resticService = ResticCommandService(
            credentialsManager: credentialsManager,
            processExecutor: ProcessExecutor()
        )
        self.repositoryCreationService = RepositoryCreationService(
            resticService: resticService,
            repositoryStorage: repositoryStorage
        )
    }
}
