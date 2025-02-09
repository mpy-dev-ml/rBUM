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

// MARK: - Backup Configuration View
/// View for configuring backup settings
private struct BackupConfigurationView: View {
    @ObservedObject var viewModel: BackupViewModel
    @State private var showingValidationAlert: Bool = false
    @State private var validationError: String = ""
    @State private var showingResetAlert: Bool = false
    
    var body: some View {
        Section("Configuration") {
            Toggle("Include Hidden Files", isOn: $viewModel.includeHidden)
                .help("When enabled, includes hidden files and directories in the backup")
                .onChange(of: viewModel.includeHidden) { _ in
                    Task {
                        await validateAndSave()
                    }
                }
            
            Toggle("Verify After Backup", isOn: $viewModel.verifyAfterBackup)
                .help("Performs integrity verification after backup completion")
                .onChange(of: viewModel.verifyAfterBackup) { _ in
                    Task {
                        await validateAndSave()
                    }
                }
            
            if let validationIssue = viewModel.configurationIssue {
                ValidationIssueView(message: validationIssue)
            }
            
            Button("Reset to Defaults") {
                showingResetAlert = true
            }
            .help("Reset all configuration settings to their default values")
        }
        .onAppear {
            viewModel.loadConfiguration()
        }
        .alert("Configuration Issue", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationError)
        }
        .alert("Reset Configuration", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values? This cannot be undone.")
        }
    }
    
    private func validateAndSave() async {
        do {
            try await viewModel.validateConfiguration()
            viewModel.saveConfiguration()
        } catch {
            validationError = error.localizedDescription
            showingValidationAlert = true
        }
    }
}

/// View for displaying validation issues
private struct ValidationIssueView: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Backup Progress View
/// View for displaying backup progress
private struct BackupProgressView: View {
    let progress: BackupProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(progress.processedFiles),
                total: Double(progress.totalFiles)
            )
            Text("Files: \(progress.processedFiles)/\(progress.totalFiles)")
            if let timeRemaining = progress.estimatedTimeRemaining {
                Text("Time remaining: \(formatDuration(timeRemaining))")
            }
            Text("Speed: \(formatSpeed(progress.speed))")
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "Unknown"
    }
    
    private func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: bytesPerSecond))/s"
    }
}

// MARK: - Backup Actions View
/// View for backup action buttons
private struct BackupActionsView: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section {
            if viewModel.backupState.isInProgress {
                if let progress = viewModel.backupProgress {
                    BackupProgressView(progress: progress)
                }
                Button(role: .destructive) {
                    viewModel.cancelBackup()
                } label: {
                    Text("Cancel Backup")
                }
            } else {
                Button {
                    viewModel.startBackup()
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Start Backup")
                    }
                }
                .disabled(!viewModel.canStartBackup)
            }
        }
    }
}

// MARK: - Backup Progress Section
/// View for displaying backup progress
private struct BackupProgressSection: View {
    @ObservedObject var viewModel: BackupViewModel
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                // Operation Description
                Text(viewModel.currentOperation)
                    .font(.headline)
                
                // Progress Bar
                if viewModel.indeterminateProgress {
                    ProgressView()
                        .progressViewStyle(.linear)
                } else {
                    ProgressView(value: viewModel.currentProgress)
                        .progressViewStyle(.linear)
                }
                
                // File Count
                if let total = viewModel.totalFiles {
                    Text("\(viewModel.processedFiles) of \(total) files processed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status-specific UI
                switch viewModel.backupStatus {
                case .completed:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Backup completed successfully")
                    }
                    
                case .failed(let error):
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Backup failed: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    }
                    
                case .cancelled:
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("Backup cancelled")
                            .foregroundColor(.orange)
                    }
                    
                default:
                    EmptyView()
                }
            }
            .padding(.vertical, 4)
            
            // Cancel Button
            if case .backing = viewModel.backupStatus {
                Button(role: .destructive) {
                    Task {
                        await viewModel.cancelBackup()
                    }
                } label: {
                    Label("Cancel Backup", systemImage: "xmark.circle")
                }
            }
        } header: {
            Text("Progress")
        }
    }
}

// MARK: - Main Backup View
/// Main view for backup configuration and control
struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPermissionAlert = false
    @State private var permissionError: String = ""
    
    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(repository: repository))
    }
    
    var body: some View {
        Form {
            BackupConfigurationView(viewModel: viewModel)
            
            if viewModel.backupStatus != nil {
                BackupProgressSection(viewModel: viewModel)
            }
            
            TagsSection(
                tags: viewModel.selectedTags,
                onRemove: viewModel.removeTag,
                onAdd: viewModel.addTag
            )
            
            BackupActionsView(viewModel: viewModel)
        }
        .padding()
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(permissionError)
        }
        .onChange(of: viewModel.error) { error in
            if let sandboxError = error as? SandboxError {
                handleSandboxError(sandboxError)
            }
        }
        .alert(
            "Error",
            isPresented: $viewModel.showError,
            actions: {
                Button("OK", action: { viewModel.dismissError() })
            },
            message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        )
    }
    
    private func handleSandboxError(_ error: SandboxError) {
        switch error {
        case .accessDenied(let message):
            permissionError = "Access Required: \(message)\n\nPlease grant access when prompted."
            showingPermissionAlert = true
            
        case .bookmarkInvalid, .bookmarkStale:
            permissionError = "Access to backup locations has expired. Please select the locations again."
            showingPermissionAlert = true
            
        case .resourceUnavailable:
            permissionError = """
                The selected backup location is no longer available.
                Please check if it exists and is accessible.
                """
            showingPermissionAlert = true
            
        case .permissionExpired:
            permissionError = "Permission to access backup locations has expired. Please grant access again."
            showingPermissionAlert = true
        }
    }
}

// MARK: - Preview Provider
struct BackupView_Previews: PreviewProvider {
    static var previews: some View {
        BackupView(
            repository: Repository(
                name: "Test Repository",
                url: URL(fileURLWithPath: "/tmp/test")
            )
        )
    }
}

// MARK: - Backup View Components
/// Component for displaying and managing backup tags
private struct TagsSection: View {
    let tags: [String]
    let onRemove: (String) -> Void
    let onAdd: () -> Void
    
    var body: some View {
        Section("Tags") {
            ForEach(tags, id: \.self) { tag in
                HStack {
                    Text(tag)
                    Spacer()
                    Button(
                        action: { onRemove(tag) },
                        label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    )
                }
            }
            Button("Add Tag", action: onAdd)
        }
    }
}

/// Component for displaying backup progress
private struct ProgressSection: View {
    let progress: BackupProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(progress.processedFiles),
                total: Double(progress.totalFiles)
            )
            Text("Files: \(progress.processedFiles)/\(progress.totalFiles)")
            if let timeRemaining = progress.estimatedTimeRemaining {
                Text("Time remaining: \(formatDuration(timeRemaining))")
            }
            Text("Speed: \(formatSpeed(progress.speed))")
        }
        .padding()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "Unknown"
    }
    
    private func formatSpeed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: bytesPerSecond))/s"
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
