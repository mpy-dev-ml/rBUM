//
//  BackupView.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

/// View for managing backup operations to a Restic repository
struct BackupView: View {
    /// View model managing the backup state and operations
    @StateObject private var viewModel: BackupViewModel
    /// Environment value for dismissing the view
    @Environment(\.dismiss) private var dismiss
    
    /// Initialize the backup view
    /// - Parameter repository: Repository to backup to
    init(repository: Repository) {
        let logger = Logging.logger(for: .repository)
        let fileManager = FileManager.default
        let resticService = ResticCommandService(
            fileManager: fileManager,
            logger: logger
        )
        let credentialsManager = KeychainCredentialsManager()
        
        _viewModel = StateObject(
            wrappedValue: BackupViewModel(
                repository: repository,
                resticService: resticService,
                credentialsManager: credentialsManager
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if case .backing = viewModel.state, 
               let progress = viewModel.currentProgress {
                VStack(spacing: 8) {
                    ProgressView(
                        value: progress.percentComplete,
                        total: 100
                    ) {
                        Text(viewModel.progressMessage)
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    
                    HStack {
                        Text(
                            "\(progress.processedFiles)/" +
                            "\(progress.totalFiles) files"
                        )
                        Spacer()
                        Text("\(Int(progress.percentComplete))%")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                Text(viewModel.progressMessage)
                    .font(.headline)
                    .padding()
            }
            
            if viewModel.selectedPaths.isEmpty {
                Button("Select Files") {
                    Task {
                        await viewModel.selectPaths()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Selected Files:")
                        .font(.headline)
                    
                    ForEach(
                        viewModel.selectedPaths,
                        id: \.absoluteString
                    ) { path in
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(path.lastPathComponent)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                HStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await viewModel.startBackup()
                        }
                    }) {
                        Text("Start Backup")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.state.isActive)
                    
                    if viewModel.state.isActive {
                        Button(action: {
                            Task {
                                await viewModel.cancelBackup()
                            }
                        }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 400)
        .padding()
        .alert("Backup Failed", isPresented: $viewModel.showError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if case .failed(let error) = viewModel.state {
                Text(error.localizedDescription)
            }
        }
    }
}

/// Preview implementation of ResticCommandService for SwiftUI previews
private final class PreviewResticCommandService: ResticCommandServiceProtocol {
    /// Initialize a new repository (no-op for preview)
    /// - Parameter credentials: Repository credentials
    func initRepository(credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    /// Check if a repository is initialized (no-op for preview)
    /// - Parameter credentials: Repository credentials
    func checkRepository(credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    /// List snapshots in a repository (returns empty list for preview)
    /// - Parameter repository: Repository to list snapshots for
    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        // Return empty list for preview
        return []
    }
    
    /// Create a backup of the given paths to the repository (simulates progress for preview)
    /// - Parameters:
    ///   - paths: Paths to backup
    ///   - repository: Repository to backup to
    ///   - tags: Optional tags for the backup
    ///   - onProgress: Optional callback for progress updates
    ///   - onStatusChange: Optional callback for status changes
    func createBackup(
        paths: [URL],
        to repository: Repository,
        tags: [String]?,
        onProgress: ((ResticBackupProgress) -> Void)?,
        onStatusChange: ((ResticBackupStatus) -> Void)?
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
    
    /// Prune snapshots in a repository (no-op for preview)
    /// - Parameters:
    ///   - repository: Repository to prune snapshots for
    ///   - keepLast: Optional number of last snapshots to keep
    ///   - keepDaily: Optional number of daily snapshots to keep
    ///   - keepWeekly: Optional number of weekly snapshots to keep
    ///   - keepMonthly: Optional number of monthly snapshots to keep
    ///   - keepYearly: Optional number of yearly snapshots to keep
    func pruneSnapshots(
        in repository: Repository,
        keepLast: Int?,
        keepDaily: Int?,
        keepWeekly: Int?,
        keepMonthly: Int?,
        keepYearly: Int?
    ) async throws {
        // No-op for preview
    }
    
    /// Check the integrity of a repository (no-op for preview)
    /// - Parameter repository: Repository to check
    func check(_ repository: Repository) async throws {
        // No-op for preview
    }
    
    /// Initialize a new repository at the given path (no-op for preview)
    /// - Parameters:
    ///   - path: Path to initialize the repository at
    ///   - password: Password for the repository
    func initializeRepository(at path: URL, password: String) async throws {
        // No-op for preview
    }
}

/// Preview implementation of KeychainCredentialsManager for SwiftUI previews
private final class PreviewCredentialsManager: KeychainCredentialsManagerProtocol {
    /// Store credentials for a repository (no-op for preview)
    /// - Parameters:
    ///   - credentials: Credentials to store
    ///   - id: ID of the repository
    func store(_ credentials: RepositoryCredentials, forRepositoryId id: String) async throws {
        // No-op for preview
    }
    
    /// Retrieve credentials for a repository (returns mock credentials for preview)
    /// - Parameter id: ID of the repository
    func retrieve(forId id: String) async throws -> RepositoryCredentials {
        // Return mock credentials for preview
        return RepositoryCredentials(
            repositoryPath: "/preview/repository",
            password: "preview"
        )
    }
    
    /// Delete credentials for a repository (no-op for preview)
    /// - Parameter id: ID of the repository
    func delete(forId id: String) async throws {
        // No-op for preview
    }
    
    /// List all stored credentials (returns empty list for preview)
    func list() async throws -> [(repositoryId: String, credentials: RepositoryCredentials)] {
        // Return empty list for preview
        return []
    }
}

#if DEBUG
struct BackupView_Previews: PreviewProvider {
    static var previews: some View {
        BackupView(repository: .preview)
            .frame(width: 400, height: 500)
    }
}

extension Repository {
    /// Preview repository for SwiftUI previews
    static var preview: Repository {
        Repository(
            id: UUID(),
            path: "/Users/preview/backups",
            name: "Preview Repository",
            description: "A repository for SwiftUI previews",
            credentials: .preview
        )
    }
}

extension RepositoryCredentials {
    /// Preview credentials for SwiftUI previews
    static var preview: RepositoryCredentials {
        RepositoryCredentials(
            repositoryPath: "/Users/preview/backups",
            password: "preview-password"
        )
    }
}
#endif
