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

        // Initialize security service first
        let securityService = DefaultSecurityService()
        
        // Initialize base services
        let keychainService = KeychainService(
            logger: logger,
            securityService: securityService
        )
        
        let bookmarkService = BookmarkService(
            logger: logger,
            securityService: securityService,
            keychainService: keychainService
        )
        
        let sandboxMonitor = SandboxMonitor(
            logger: logger,
            securityService: securityService
        )

        // Update security service with dependencies
        securityService.configure(
            logger: logger,
            bookmarkService: bookmarkService,
            keychainService: keychainService,
            sandboxMonitor: sandboxMonitor
        )

        // Initialize dependent services
        let xpcService = ResticXPCService(
            securityService: securityService,
            sandboxMonitor: sandboxMonitor,
            logger: logger
        )

        let resticService = ResticCommandService(
            securityService: securityService,
            xpcService: xpcService,
            keychainService: keychainService,
            fileManager: fileManager,
            logger: logger
        )

        let backupService = BackupService(
            resticService: resticService,
            keychainService: keychainService,
            logger: logger
        )

        let credentialsManager = KeychainCredentialsManager(
            keychainService: keychainService,
            logger: logger
        )

        _viewModel = StateObject(
            wrappedValue: BackupViewModel(
                repository: repository,
                backupService: backupService,
                credentialsService: credentialsManager,
                securityService: securityService,
                bookmarkService: bookmarkService,
                logger: logger
            )
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            if viewModel.backupState.isInProgress {
                VStack(spacing: 8) {
                    ProgressView(
                        value: viewModel.backupState.progress?.percentComplete ?? 0,
                        total: 100
                    ) {
                        Text(viewModel.backupState.progressMessage)
                            .font(.headline)
                    }
                    .progressViewStyle(.linear)

                    HStack {
                        Text(
                            "\(viewModel.backupState.progress?.processedFiles ?? 0)/" +
                                "\(viewModel.backupState.progress?.totalFiles ?? 0) files"
                        )
                        Spacer()
                        Text("\(Int(viewModel.backupState.progress?.percentComplete ?? 0))%")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                Text(viewModel.backupState.progressMessage)
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
                    .disabled(viewModel.backupState.isInProgress)

                    if viewModel.backupState.isInProgress {
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
        .alert("Backup Failed", isPresented: $viewModel.showErrorAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(viewModel.backupState.errorMessage ?? "An unknown error occurred")
        }
    }
}

#Preview {
    BackupView(
        repository: Repository(
            name: "Test Repository",
            url: URL(fileURLWithPath: "/tmp/test"),
            credentials: RepositoryCredentials(
                username: "test",
                password: "test"
            )
        )
    )
    .frame(width: 400, height: 500)
}
