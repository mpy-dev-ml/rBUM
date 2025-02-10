import Core
import SwiftUI

@MainActor
class FileSearchViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var searchResults: [FileMatch] = []
    @Published private(set) var selectedFile: FileMatch?
    @Published private(set) var fileVersions: [FileVersion] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingVersions = false
    @Published private(set) var error: Error?
    @Published var searchPattern = ""
    @Published private(set) var repositories: [Repository] = []
    @Published var selectedRepository: Repository?

    // MARK: - Dependencies

    private let fileSearchService: FileSearchServiceProtocol
    private let restoreService: RestoreServiceProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let logger: LoggerProtocol

    // MARK: - Initialisation

    init(
        fileSearchService: FileSearchServiceProtocol,
        restoreService: RestoreServiceProtocol,
        repositoryStorage: RepositoryStorageProtocol,
        logger: LoggerProtocol
    ) {
        self.fileSearchService = fileSearchService
        self.restoreService = restoreService
        self.repositoryStorage = repositoryStorage
        self.logger = logger

        // Load repositories
        Task {
            await loadRepositories()
        }
    }

    // MARK: - Public Methods

    /// Load available repositories
    @MainActor
    private func loadRepositories() async {
        do {
            repositories = try await repositoryStorage.loadRepositories()
            if let firstRepo = repositories.first {
                selectedRepository = firstRepo
            }
        } catch {
            logger.error("Failed to load repositories: \(error.localizedDescription)", privacy: .public)
            self.error = error
        }
    }

    /// Search for files matching the current pattern
    func performSearch() async {
        guard !searchPattern.isEmpty,
              let repository = selectedRepository else { return }

        isSearching = true
        error = nil

        do {
            searchResults = try await fileSearchService.searchFile(
                pattern: searchPattern,
                in: repository
            )
            logger.info("Found \(searchResults.count) matches", privacy: .public)
        } catch {
            logger.error("Search failed: \(error.localizedDescription)", privacy: .public)
            self.error = error
        }

        isSearching = false
    }

    /// Load all versions of the selected file
    func loadFileVersions() async {
        guard let selectedFile else { return }

        isLoadingVersions = true
        error = nil

        do {
            fileVersions = try await fileSearchService.getFileVersions(
                path: selectedFile.path,
                in: selectedFile.snapshot.repository
            )
            logger.info("Found \(fileVersions.count) versions", privacy: .public)
        } catch {
            logger.error("Loading versions failed: \(error.localizedDescription)", privacy: .public)
            self.error = error
        }

        isLoadingVersions = false
    }

    /// Select a file from search results
    func selectFile(_ file: FileMatch) {
        selectedFile = file
        Task {
            await loadFileVersions()
        }
    }

    /// Restore selected version to specified location
    func restoreVersion(_ version: FileVersion, to destination: URL) async {
        error = nil

        do {
            try await restoreService.restore(
                snapshot: version.snapshot,
                from: version.snapshot.repository,
                paths: [version.path],
                to: destination.path
            )
            logger.info("Successfully restored file", privacy: .public)
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)", privacy: .public)
            self.error = error
        }
    }

    /// Clear current search results and selection
    func clearSearch() {
        searchPattern = ""
        searchResults = []
        selectedFile = nil
        fileVersions = []
        error = nil
    }
}
