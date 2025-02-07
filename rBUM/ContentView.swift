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

    init(
        credentialsManager: KeychainCredentialsManagerProtocol,
        creationService: RepositoryCreationServiceProtocol
    ) {
        self.credentialsManager = credentialsManager
        self.creationService = creationService
        _viewModel = StateObject(
            wrappedValue: ContentViewModel(
                credentialsManager: credentialsManager
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $viewModel.selectedSidebarItem
            )
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
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
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
            "folder"
        case .backups:
            "arrow.clockwise"
        case .schedules:
            "calendar"
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
    func save(_: Repository) throws {
        // No-op for preview
    }

    func delete(_: Repository) throws {
        // No-op for preview
    }

    func get(forId _: String) throws -> Repository? {
        // Return nil for preview
        nil
    }

    func store(_: Repository) throws {
        // No-op for preview
    }

    func retrieve(forId _: UUID) throws -> Repository? {
        // Return nil for preview
        nil
    }

    func list() throws -> [Repository] {
        // Return empty list for preview
        []
    }

    func delete(forId _: UUID) throws {}
    func exists(atPath _: URL, excludingId _: UUID?) throws -> Bool {
        // Always return false for preview
        false
    }
}

private final class PreviewRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(
        name: String,
        path: String,
        password: String
    ) async throws -> Repository {
        // Create a preview repository
        Repository(
            name: name,
            path: path,
            credentials: RepositoryCredentials(
                repositoryPath: path,
                password: password
            )
        )
    }

    func importRepository(
        name: String,
        path: String,
        password: String
    ) async throws -> Repository {
        // Import a preview repository (same as create for preview)
        Repository(
            name: name,
            path: path,
            credentials: RepositoryCredentials(
                repositoryPath: path,
                password: password
            )
        )
    }

    func createRepository(
        name: String,
        path: URL,
        password: String
    ) async throws -> Repository {
        Repository(
            name: name,
            path: path.path,
            credentials: RepositoryCredentials(
                repositoryPath: path.path,
                password: password
            )
        )
    }

    func importRepository(
        name: String,
        path: URL,
        password: String
    ) async throws -> Repository {
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
    func initRepository(
        credentials _: RepositoryCredentials
    ) async throws {
        // No-op for preview
    }

    func checkRepository(
        credentials _: RepositoryCredentials
    ) async throws {
        // No-op for preview
    }

    func listSnapshots(
        in _: Repository
    ) async throws -> [ResticSnapshot] {
        // Return empty list for preview
        []
    }

    func initializeRepository(
        at _: URL,
        password _: String
    ) async throws {}

    func check(
        _: Repository
    ) async throws {
        // No-op for preview
    }

    func createBackup(
        paths _: [URL],
        to _: Repository,
        tags _: [String]? = nil,
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
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        onStatusChange?(.completed)
    }

    func pruneSnapshots(
        in _: Repository,
        keepLast _: Int?,
        keepDaily _: Int?,
        keepWeekly _: Int?,
        keepMonthly _: Int?,
        keepYearly _: Int?
    ) async throws {}

    func forget(
        in _: Repository,
        snapshots _: [ResticSnapshot]
    ) async throws {}

    func restore(
        from _: ResticSnapshot,
        to _: URL,
        onProgress _: ((ResticRestoreProgress) -> Void)? = nil
    ) async throws {}

    func mount(
        repository _: Repository,
        on _: URL,
        onProgress _: ((ResticMountProgress) -> Void)? = nil
    ) async throws {}

    func unmount(
        repository _: Repository,
        on _: URL
    ) async throws {}
}

private final class PreviewCredentialsManager: KeychainCredentialsManagerProtocol {
    func store(
        _: RepositoryCredentials,
        forRepositoryId _: String
    ) async throws {
        // No-op for preview
    }

    func retrieve(
        forId _: String
    ) async throws -> RepositoryCredentials {
        // Return dummy data for preview
        RepositoryCredentials(repositoryPath: "/tmp/preview", password: "preview")
    }

    func delete(
        forId _: String
    ) async throws {
        // No-op for preview
    }

    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        // Return empty list for preview
        []
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
        repositoryStorage = RepositoryStorage()
        resticService = ResticCommandService(
            fileManager: .default,
            logger: Logging.logger(for: .repository)
        )
        repositoryCreationService = RepositoryCreationService(
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
