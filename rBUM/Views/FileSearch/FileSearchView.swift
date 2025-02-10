import Core
import QuickLook
import SwiftUI

struct FileSearchView: View {
    @StateObject private var viewModel: FileSearchViewModel
    @State private var previewURL: URL?
    @State private var showingRestoreSheet = false
    @State private var selectedVersion: FileVersion?

    init(
        fileSearchService: FileSearchServiceProtocol,
        restoreService: RestoreServiceProtocol,
        logger: LoggerProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: FileSearchViewModel(
                fileSearchService: fileSearchService,
                restoreService: restoreService,
                logger: logger
            )
        )
    }

    var body: some View {
        NavigationSplitView {
            // Search sidebar
            VStack {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search files...", text: $viewModel.searchPattern)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task {
                                await viewModel.performSearch()
                            }
                        }

                    if !viewModel.searchPattern.isEmpty {
                        Button {
                            viewModel.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding([.horizontal, .top])

                // Results list
                List(viewModel.searchResults, selection: $viewModel.selectedFile) { file in
                    FileMatchRow(file: file)
                        .tag(file)
                }
            }
        } detail: {
            // File versions detail
            if let selectedFile = viewModel.selectedFile {
                FileVersionsView(
                    versions: viewModel.fileVersions,
                    selectedVersion: $selectedVersion,
                    showingRestoreSheet: $showingRestoreSheet,
                    previewURL: $previewURL
                )
            } else {
                ContentUnavailableView(
                    "No File Selected",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select a file to view its versions")
                )
            }
        }
        .navigationTitle("File Search")
        .sheet(isPresented: $showingRestoreSheet) {
            if let version = selectedVersion {
                RestoreSheet(version: version, viewModel: viewModel)
            }
        }
        .quickLookPreview($previewURL)
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
}

/// Row view for a file match in the search results
struct FileMatchRow: View {
    let file: FileMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(file.path)
                .font(.body)

            HStack {
                Text(file.modTime, style: .date)
                Text("•")
                Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// View for displaying file versions
struct FileVersionsView: View {
    let versions: [FileVersion]
    @Binding var selectedVersion: FileVersion?
    @Binding var showingRestoreSheet: Bool
    @Binding var previewURL: URL?

    var body: some View {
        List(versions) { version in
            FileVersionRow(version: version)
                .contextMenu {
                    Button {
                        selectedVersion = version
                        showingRestoreSheet = true
                    } label: {
                        Label("Restore...", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        Task {
                            // Create a temporary file for preview
                            let tempDir = FileManager.default.temporaryDirectory
                            let tempFile = tempDir.appendingPathComponent(
                                version.path.components(separatedBy: "/").last ?? "file"
                            )

                            do {
                                // Restore file to temporary location
                                try await viewModel.restoreVersion(version, to: tempDir)
                                previewURL = tempFile
                            } catch {
                                // Handle error (already handled by view model)
                                logger.error("Preview failed: \(error.localizedDescription)", privacy: .public)
                            }
                        }
                    } label: {
                        Label("Quick Look", systemImage: "eye")
                    }
                }
        }
        .navigationTitle("File Versions")
        .overlay {
            if versions.isEmpty {
                ContentUnavailableView(
                    "No Versions Found",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("No versions of this file were found in the backup")
                )
            }
        }
    }
}

/// Row view for a file version
struct FileVersionRow: View {
    let version: FileVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(version.modTime, style: .date)
                .font(.headline)

            HStack {
                Text(ByteCountFormatter.string(fromByteCount: Int64(version.size), countStyle: .file))
                Text("•")
                Text(version.snapshot.id.prefix(8))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Sheet for restoring a file version
struct RestoreSheet: View {
    let version: FileVersion
    let viewModel: FileSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var destinationURL: URL?

    var body: some View {
        NavigationStack {
            VStack {
                Text("Choose where to restore:")
                    .font(.headline)

                Text(version.path)
                    .font(.body)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.prompt = "Choose"

                    if panel.runModal() == .OK {
                        destinationURL = panel.url

                        Task {
                            if let url = destinationURL {
                                await viewModel.restoreVersion(version, to: url)
                                dismiss()
                            }
                        }
                    }
                } label: {
                    Text("Choose Destination...")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .frame(width: 400, height: 300)
            .navigationTitle("Restore File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
