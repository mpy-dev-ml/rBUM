//
//  BackupView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(
            repository: repository,
            resticService: ResticCommandService(
                fileManager: .default,
                logger: Logging.logger(for: .repository)
            ),
            credentialsManager: KeychainCredentialsManager()
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if case .backing = viewModel.state, let progress = viewModel.currentProgress {
                VStack(spacing: 8) {
                    ProgressView(value: progress.percentComplete, total: 100) {
                        Text(viewModel.progressMessage)
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)
                    
                    HStack {
                        Text("\(progress.processedFiles)/\(progress.totalFiles) files")
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
                VStack(spacing: 12) {
                    ForEach(viewModel.selectedPaths, id: \.absoluteString) { path in
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
                    Button("Start Backup") {
                        Task {
                            await viewModel.startBackup()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.state.isActive)
                    
                    if viewModel.state.isActive {
                        Button("Cancel") {
                            Task {
                                await viewModel.cancelBackup()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
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
}

private final class PreviewCredentialsManager: CredentialsManagerProtocol {
    func store(_ credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
        // Return mock credentials for preview
        return RepositoryCredentials(
            repositoryId: id,
            password: "preview",
            repositoryPath: "/preview/repository"
        )
    }
    
    func update(_ credentials: RepositoryCredentials) async throws {
        // No-op for preview
    }
    
    func delete(forId id: UUID) async throws {
        // No-op for preview
    }
    
    func getPassword(forRepositoryId id: UUID) async throws -> String {
        // Return mock password for preview
        return "preview"
    }
    
    func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
        RepositoryCredentials(
            repositoryId: id,
            password: password,
            repositoryPath: path
        )
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

// MARK: - Preview

#Preview {
    BackupView(repository: Repository(
        name: "Test Repository",
        path: URL(fileURLWithPath: "/test/repo")
    ))
    .frame(width: 400, height: 500)
}
