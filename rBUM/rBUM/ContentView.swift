//
//  ContentView.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem? = .repositories
    
    private let repositoryStorage: RepositoryStorageProtocol
    private let repositoryCreationService: RepositoryCreationServiceProtocol
    private let resticService: ResticCommandServiceProtocol
    
    init(
        repositoryStorage: RepositoryStorageProtocol,
        repositoryCreationService: RepositoryCreationServiceProtocol,
        resticService: ResticCommandServiceProtocol
    ) {
        self.repositoryStorage = repositoryStorage
        self.repositoryCreationService = repositoryCreationService
        self.resticService = resticService
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            switch selectedSidebarItem {
            case .repositories:
                RepositoryListView(
                    repositoryStorage: repositoryStorage,
                    creationService: repositoryCreationService,
                    resticService: resticService
                )
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
        repositoryStorage: PreviewRepositoryStorage(),
        repositoryCreationService: PreviewRepositoryCreationService(),
        resticService: PreviewResticCommandService()
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
    func initializeRepository(_ repository: Repository, password: String) async throws {}
    func checkRepository(_ repository: Repository) async throws -> Bool { true }
    func createBackup(for repository: Repository, paths: [String]) async throws {}
}
