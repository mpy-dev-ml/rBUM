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
        credentialsManager: PreviewCredentialsManager()
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
    func listSnapshots(in repository: ResticRepository) async throws -> [ResticSnapshot] {
        return []
    }
    
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func check(_ repository: ResticRepository) async throws {}
    
    func createBackup(
        paths: [URL],
        to repository: ResticRepository,
        tags: [String]? = nil,
        onProgress: ((ResticBackupProgress) -> Void)? = nil,
        onStatusChange: ((ResticBackupStatus) -> Void)? = nil
    ) async throws {
        // Simulate backup progress
        onStatusChange?(.preparing)
        
        // Simulate progress updates
        let progress = ResticBackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024,
            currentFile: "/test/file.txt",
            startTime: Date(),
            updatedAt: Date()
        )
        onProgress?(progress)
        onStatusChange?(.backing(progress))
        
        // Simulate completion
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second delay
        onStatusChange?(.completed)
    }
    
    func pruneSnapshots(
        in repository: ResticRepository,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {}
    
    func forget(in repository: ResticRepository, snapshots: [ResticSnapshot]) async throws {}
    
    func restore(from snapshot: ResticSnapshot, to path: URL, onProgress: ((ResticRestoreProgress) -> Void)? = nil) async throws {}
    
    func mount(repository: ResticRepository, on path: URL, onProgress: ((ResticMountProgress) -> Void)? = nil) async throws {}
    
    func unmount(repository: ResticRepository, on path: URL) async throws {}
}

private final class PreviewCredentialsManager: CredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials) async throws {
        <#code#>
    }
    
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
        <#code#>
    }
    
    func delete(forId id: UUID) async throws {
        <#code#>
    }
    
    func getPassword(forRepositoryId id: UUID) async throws -> String {
        <#code#>
    }
    
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
        <#code#>
    }
    
    func getCredentials(for repository: Repository) throws -> RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: repository.id,
            password: "test",
            repositoryPath: repository.path.path
        )
    }
    
    func storeCredentials(_ credentials: RepositoryCredentials) throws {}
    
    func deleteCredentials(forRepositoryId repositoryId: UUID) throws {}
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
            fileManager: .default,
            logger: Logging.logger(for: .repository)
        )
        self.repositoryCreationService = RepositoryCreationService(
            resticService: resticService,
            repositoryStorage: repositoryStorage
        )
    }
}
