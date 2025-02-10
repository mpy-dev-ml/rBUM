import Core
import SwiftUI

struct ContentView: View {
    // MARK: - Properties

    private let credentialsManager: KeychainCredentialsManagerProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let resticService: ResticCommandServiceProtocol
    private let repositoryCreationService: RepositoryCreationServiceProtocol
    private let fileSearchService: FileSearchServiceProtocol
    private let restoreService: RestoreServiceProtocol

    @State private var selectedTab: Tab = .backups

    // MARK: - Initialisation

    init(
        credentialsManager: KeychainCredentialsManagerProtocol,
        repositoryStorage: RepositoryStorageProtocol,
        resticService: ResticCommandServiceProtocol,
        repositoryCreationService: RepositoryCreationServiceProtocol,
        fileSearchService: FileSearchServiceProtocol,
        restoreService: RestoreServiceProtocol
    ) {
        self.credentialsManager = credentialsManager
        self.repositoryStorage = repositoryStorage
        self.resticService = resticService
        self.repositoryCreationService = repositoryCreationService
        self.fileSearchService = fileSearchService
        self.restoreService = restoreService
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.icon)
                }
            }
            .navigationTitle("rBUM")
        } detail: {
            selectedDetailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Private Views

    @ViewBuilder
    private var selectedDetailView: some View {
        switch selectedTab {
        case .backups:
            BackupsView(
                credentialsManager: credentialsManager,
                repositoryStorage: repositoryStorage,
                resticService: resticService,
                repositoryCreationService: repositoryCreationService
            )
        case .search:
            FileSearchView(
                fileSearchService: fileSearchService,
                restoreService: restoreService,
                logger: LoggerFactory.createLogger(category: "FileSearch")
            )
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Tab Enum

extension ContentView {
    enum Tab: String, CaseIterable, Identifiable {
        case backups
        case search
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .backups:
                "Backups"
            case .search:
                "Search Files"
            case .settings:
                "Settings"
            }
        }

        var icon: String {
            switch self {
            case .backups:
                "arrow.clockwise.circle"
            case .search:
                "magnifyingglass"
            case .settings:
                "gear"
            }
        }
    }
}

#Preview {
    ContentView(
        credentialsManager: PreviewMocks.credentialsManager,
        repositoryStorage: PreviewMocks.repositoryStorage,
        resticService: PreviewMocks.resticService,
        repositoryCreationService: PreviewMocks.repositoryCreationService,
        fileSearchService: PreviewMocks.fileSearchService,
        restoreService: PreviewMocks.restoreService
    )
}
