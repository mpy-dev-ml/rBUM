//
//  ContentView.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 29/01/2025.
//

import Core
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    private let credentialsManager: KeychainCredentialsManagerProtocol
    private let creationService: RepositoryCreationServiceProtocol
    
    init(credentialsManager: KeychainCredentialsManagerProtocol,
         creationService: RepositoryCreationServiceProtocol) {
        self.credentialsManager = credentialsManager
        self.creationService = creationService
        _viewModel = StateObject(wrappedValue: ContentViewModel(credentialsManager: credentialsManager))
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $viewModel.selectedSidebarItem)
        } detail: {
            switch viewModel.selectedSidebarItem {
            case .repositories:
                RepositoryListView(
                    credentialsManager: credentialsManager,
                    creationService: creationService
                )
            case .backups:
                BackupListView()
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

// MARK: - Preview Helpers

private final class PreviewRepositoryStorage: RepositoryStorageProtocol {
    func save(_ repository: Repository) throws {
        // No-op for preview
    }
    
    func delete(_ repository: Repository) throws {
        // No-op for preview
    }
    
    func get(forId id: String) throws -> Repository? {
        // Return nil for preview
        return nil
    }
    
    func store(_ repository: Repository) throws {}
    func retrieve(forId id: UUID) throws -> Repository? { nil }
    func list() throws -> [Repository] { 
        // Return empty list for preview
        return [] 
    }
    
    func delete(forId id: UUID) throws {}
    func exists(atPath path: URL, excludingId: UUID?) throws -> Bool { 
        // Always return false for preview
        return false 
    }
}

private final class PreviewRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(name: String, path: String, password: String) async throws -> Repository {
        // Create a preview repository
        return Repository(
            name: name,
            path: path,
            credentials: RepositoryCredentials(
                repositoryPath: path,
                password: password
            )
        )
    }
    
    func importRepository(name: String, path: String, password: String) async throws -> Repository {
        // Import a preview repository (same as create for preview)
        return Repository(
            name: name,
            path: path,
            credentials: RepositoryCredentials(
                repositoryPath: path,
                password: password
            )
        )
    }
    
    func createRepository(name: String, path: URL, password: String) async throws -> Repository {
        Repository(
            name: name,
            path: path.path,
            credentials: RepositoryCredentials(
                repositoryPath: path.path,
                password: password
            )
        )
    }
    
    func importRepository(name: String, path: URL, password: String) async throws -> Repository {
        Repository(
            name: name,
            path: path.path,
            credentials: RepositoryCredentials(
                repositoryPath: path.path,
                password: password
            )
        )
    }
}

private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    func initRepository(credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    func checkRepository(credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        // Return empty list for preview
        return []
    }
    
    func initializeRepository(at path: URL, password: String) async throws {}
    
    func check(_ repository: Repository) async throws {
        // No-op for preview
    }
    
    func createBackup(
        paths: [URL],
        to repository: Repository,
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
        in repository: Repository,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {}
    
    func forget(in repository: Repository, snapshots: [ResticSnapshot]) async throws {}
    
    func restore(from snapshot: ResticSnapshot, to path: URL, onProgress: ((ResticRestoreProgress) -> Void)? = nil) async throws {}
    
    func mount(repository: Repository, on path: URL, onProgress: ((ResticMountProgress) -> Void)? = nil) async throws {}
    
    func unmount(repository: Repository, on path: URL) async throws {}
}

private final class PreviewCredentialsManager: KeychainCredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        // No-op for preview
    }
    
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        // Return dummy data for preview
        return RepositoryCredentials(repositoryPath: "/tmp/preview", password: "preview")
    }
    
    func delete(forId id: String) async throws {
        // No-op for preview
    }
    
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        // Return empty list for preview
        return []
    }
}

class ContentViewModel: ObservableObject {
    @Published var selectedSidebarItem: SidebarItem? = .repositories
    
    let repositoryStorage: RepositoryStorageProtocol
    let repositoryCreationService: RepositoryCreationServiceProtocol
    let resticService: ResticCommandServiceProtocol
    let credentialsManager: KeychainCredentialsManagerProtocol
    
    init(credentialsManager: KeychainCredentialsManagerProtocol) {
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

#Preview {
    ContentView(
        credentialsManager: PreviewCredentialsManager(),
        creationService: PreviewRepositoryCreationService()
    )
}
