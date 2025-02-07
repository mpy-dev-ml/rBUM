//
//  BackupView.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 7 February 2025
//

import Core
import OSLog
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
        let logger = Logger(subsystem: "dev.mpy.rBUM", category: "backup")
        let fileManager = FileManager.default
        
        let keychainService = KeychainService(
            logger: logger as LoggerProtocol
        )
        
        let bookmarkService = BookmarkService(
            logger: logger as LoggerProtocol
        )
        
        let securityService = DefaultSecurityService(
            logger: logger as LoggerProtocol,
            bookmarkService: bookmarkService,
            keychainService: keychainService
        )
        
        let xpcService = ResticXPCService(
            logger: logger as LoggerProtocol,
            securityService: securityService
        )
        
        let resticService = ResticCommandService(
            logger: logger as LoggerProtocol,
            securityService: securityService,
            xpcService: xpcService,
            keychainService: keychainService,
            fileManager: fileManager
        )
        
        let backupService = BackupService(
            resticService: resticService,
            logger: logger as LoggerProtocol
        )
        
        let credentialsManager = KeychainCredentialsManager(
            keychainService: keychainService,
            logger: logger as LoggerProtocol
        )

        _viewModel = StateObject(
            wrappedValue: BackupViewModel(
                repository: repository,
                backupService: backupService,
                credentialsService: credentialsManager,
                securityService: securityService,
                bookmarkService: bookmarkService,
                logger: logger as LoggerProtocol
            )
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            if case .inProgress(let progress) = viewModel.state {
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
                Button(
                    role: .none,
                    action: {
                        Task {
                            await viewModel.selectPaths()
                        }
                    },
                    label: {
                        Text("Select Files")
                            .frame(maxWidth: .infinity)
                    }
                )
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
                    Button(
                        role: .none,
                        action: {
                            Task {
                                await viewModel.startBackup()
                            }
                        },
                        label: {
                            Text("Start Backup")
                                .frame(maxWidth: .infinity)
                        }
                    )
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBackupInProgress)

                    if viewModel.isBackupInProgress {
                        Button(
                            role: .cancel,
                            action: {
                                Task {
                                    await viewModel.cancelBackup()
                                }
                            },
                            label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                            }
                        )
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
            if case let .failed(error) = viewModel.state {
                Text(error.localizedDescription)
            }
        }
    }
}

#Preview {
    BackupView(
        repository: Repository(
            id: UUID(),
            name: "Test Repository",
            path: "/tmp/test",
            url: URL(fileURLWithPath: "/tmp/test"),
            credentials: RepositoryCredentials(
                username: "test",
                password: "test"
            )
        )
    )
    .frame(width: 400, height: 500)
}
