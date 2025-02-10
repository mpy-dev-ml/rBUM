import SwiftUI

public struct RepositoryDiscoveryView: View {
    @StateObject private var viewModel: RepositoryDiscoveryViewModel
    @State private var showingDirectoryPicker = false
    @State private var isRecursive = true
    @State private var selectedRepository: DiscoveredRepository?
    @State private var showingError = false

    public init(viewModel: RepositoryDiscoveryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            // Content
            contentSection

            // Footer
            footerSection
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }

    // MARK: - Private Views

    private var headerSection: some View {
        HStack {
            Button("Select Directory") {
                showingDirectoryPicker = true
            }
            .fileImporter(
                isPresented: $showingDirectoryPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    if let url = urls.first {
                        viewModel.startScan(at: url, recursive: isRecursive)
                    }
                case let .failure(error):
                    viewModel.error = .discoveryFailed(error.localizedDescription)
                    showingError = true
                }
            }

            Toggle("Include Subdirectories", isOn: $isRecursive)
                .toggleStyle(.switch)
        }
    }

    private var contentSection: some View {
        VStack {
            switch viewModel.scanningStatus {
            case .idle:
                Text("Select a directory to scan for Restic repositories")
                    .foregroundColor(.secondary)

            case let .scanning(progress):
                VStack {
                    ProgressView()
                    Text("Scanned \(progress.scannedItems) items")
                    Text("Found \(progress.foundRepositories) repositories")
                }

            case .processing:
                ProgressView("Processing discovered repositories...")

            case let .completed(count):
                if !isEmpty {
                    repositoryList
                } else {
                    Text("No repositories found")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var repositoryList: some View {
        List(viewModel.discoveredRepositories, selection: $selectedRepository) { repository in
            RepositoryListItem(repository: repository)
                .contextMenu {
                    Button("Add to App") {
                        Task {
                            do {
                                try await viewModel.addRepository(repository)
                            } catch {
                                viewModel.error = error as? RepositoryDiscoveryError
                                showingError = true
                            }
                        }
                    }
                }
        }
    }

    private var footerSection: some View {
        HStack {
            if case .scanning = viewModel.scanningStatus {
                Button("Cancel") {
                    viewModel.cancelScan()
                }
            }

            Spacer()

            if let repository = selectedRepository {
                Button("Add Repository") {
                    Task {
                        do {
                            try await viewModel.addRepository(repository)
                        } catch {
                            viewModel.error = error as? RepositoryDiscoveryError
                            showingError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Repository List Item

private struct RepositoryListItem: View {
    let repository: DiscoveredRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(repository.url.path)
                .font(.headline)

            HStack {
                Label {
                    Text(formatSize(repository.metadata.size))
                } icon: {
                    Image(systemName: "externaldrive")
                }

                if let snapshots = repository.metadata.snapshotCount {
                    Label {
                        Text("\(snapshots) snapshots")
                    } icon: {
                        Image(systemName: "clock")
                    }
                }

                if let modified = repository.metadata.lastModified {
                    Label {
                        Text("Modified \(formatDate(modified))")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Private Methods

    private func formatSize(_ size: UInt64?) -> String {
        guard let size else { return "Unknown size" }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    RepositoryDiscoveryView(
        viewModel: RepositoryDiscoveryViewModel(
            discoveryService: PreviewRepositoryDiscoveryService()
        )
    )
}
