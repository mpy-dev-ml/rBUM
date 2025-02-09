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
    
    var body: some View {
        Section("Configuration") {
            Toggle("Include Hidden Files", isOn: $viewModel.includeHidden)
            
            Button {
                viewModel.showSourcePicker()
            } label: {
                HStack {
                    Text("Select Source")
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                }
            }
            
            ForEach(viewModel.selectedSources, id: \.self) { source in
                HStack {
                    Text(source.lastPathComponent)
                    Spacer()
                    Button {
                        viewModel.removeSource(source)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
        }
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

// MARK: - Main Backup View
/// Main view for backup configuration and control
struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(repository: Repository) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(repository: repository))
    }
    
    var body: some View {
        Form {
            BackupConfigurationView(viewModel: viewModel)
            
            TagsSection(
                tags: viewModel.selectedTags,
                onRemove: viewModel.removeTag,
                onAdd: viewModel.addTag
            )
            
            BackupActionsView(viewModel: viewModel)
        }
        .padding()
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
