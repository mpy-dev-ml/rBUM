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
    func save(_ repository: Repository) throws {}
    func delete(_ repository: Repository) throws {}
    func list() throws -> [Repository] { [] }
    func get(forId id: UUID) throws -> Repository? { nil }
    func exists(atPath path: URL, excludingId id: UUID?) throws -> Bool { false }
}

private final class PreviewRepositoryCreationService: RepositoryCreationServiceProtocol {
    func createRepository(
        name: String,
        url: URL,
        username: String,
        password: String
    ) async throws -> Repository {
        Repository(
            id: UUID(),
            name: name,
            path: url.path,
            credentials: RepositoryCredentials(
                username: username,
                password: password
            )
        )
    }

    func importRepository(
        name: String,
        url: URL,
        username: String,
        password: String
    ) async throws -> Repository {
        Repository(
            id: UUID(),
            name: name,
            path: url.path,
            credentials: RepositoryCredentials(
                username: username,
                password: password
            )
        )
    }
}

private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    func initRepository(credentials: RepositoryCredentials) async throws {}
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] { [] }
    func check(repository: Repository) async throws {}
    func createBackup(
        paths: [URL],
        to repository: Repository,
        tags: [String]?,
        onProgress: ((ResticBackupProgress) -> Void)?,
        onStatusChange: ((ResticBackupStatus) -> Void)?
    ) async throws {}
    func pruneSnapshots(
        in repository: Repository,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {}
    func forget(in repository: Repository, snapshots: [ResticSnapshot]) async throws {}
    func restore(
        from snapshot: ResticSnapshot,
        to path: URL,
        onProgress: ((ResticRestoreProgress) -> Void)?
    ) async throws {}
    func mount(
        repository: Repository,
        on path: URL,
        onProgress: ((ResticMountProgress) -> Void)?
    ) async throws {}
    func unmount(repository: Repository, on path: URL) async throws {}
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

    private let logger = Logger(subsystem: "dev.mpy.rBUM", category: "repository")
    private let fileManager = FileManager.default

    let repositoryStorage: any RepositoryStorageProtocol
    let repositoryCreationService: any RepositoryCreationServiceProtocol
    let resticService: any ResticCommandServiceProtocol
    let credentialsManager: KeychainCredentialsManagerProtocol

    init(credentialsManager: KeychainCredentialsManagerProtocol) {
        self.credentialsManager = credentialsManager

        let storage = RepositoryStorage()
        repositoryStorage = storage

        let securityService = DefaultSecurityService()
        let xpcService = ResticXPCService()
        let keychainService = KeychainService()

        let commandService = ResticCommandService(
            logger: logger,
            securityService: securityService,
            xpcService: xpcService,
            keychainService: keychainService,
            fileManager: fileManager
        )
        resticService = commandService

        repositoryCreationService = RepositoryCreationService(
            resticService: commandService,
            repositoryStorage: storage
        )
    }
}

#Preview {
    ContentView(
        credentialsManager: PreviewCredentialsManager(),
        creationService: PreviewRepositoryCreationService()
    )
}
