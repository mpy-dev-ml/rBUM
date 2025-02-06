//
//  PermissionRequestView.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import SwiftUI
import Core

/// View for requesting user permission to access files and directories
struct PermissionRequestView: View {
    let url: URL
    let onGranted: () -> Void
    let onDenied: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PermissionRequestViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon and Title
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Permission Required")
                .font(.title)
                .bold()
            
            // Description
            Text("rBUM needs permission to access:")
                .font(.headline)
            
            Text(url.path)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal)
            
            // Explanation
            Text("This permission is needed to:")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                PermissionBulletPoint(text: "Create backups of your files")
                PermissionBulletPoint(text: "Restore files from backups")
                PermissionBulletPoint(text: "Monitor changes for automatic backups")
            }
            .padding(.horizontal)
            
            // Privacy Note
            Text("Your privacy is protected:")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                PermissionBulletPoint(text: "Access is limited to selected items only")
                PermissionBulletPoint(text: "Permissions can be revoked at any time")
                PermissionBulletPoint(text: "All data remains on your device")
            }
            .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 16) {
                Button(role: .cancel) {
                    onDenied()
                    dismiss()
                } label: {
                    Text("Deny")
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
                
                Button {
                    Task {
                        if await viewModel.requestPermission(for: url) {
                            onGranted()
                        } else {
                            onDenied()
                        }
                        dismiss()
                    }
                } label: {
                    Text("Allow")
                        .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 400)
    }
}

/// Bullet point view for permission explanations
private struct PermissionBulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

/// View model for handling permission requests
class PermissionRequestViewModel: ObservableObject {
    private let securityService: SecurityServiceProtocol
    private let logger: LoggerProtocol
    
    init(
        securityService: SecurityServiceProtocol = SecurityService(),
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "PermissionRequest")
    ) {
        self.securityService = securityService
        self.logger = logger
    }
    
    /// Request permission for a URL
    /// - Parameter url: The URL to request permission for
    /// - Returns: true if permission was granted, false otherwise
    func requestPermission(for url: URL) async -> Bool {
        do {
            return try await securityService.requestPermission(for: url)
        } catch {
            logger.error("Failed to request permission: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }
}

#Preview {
    PermissionRequestView(
        url: URL(fileURLWithPath: "/Users/example/Documents"),
        onGranted: {},
        onDenied: {}
    )
}
