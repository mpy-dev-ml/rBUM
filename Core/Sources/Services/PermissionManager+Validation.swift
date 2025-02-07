import Foundation

extension PermissionManager {
    // MARK: - Validation

    func validateFileAccess(for url: URL) async throws {
        try await validateFileExists(at: url)
        try await validateFilePermissions(for: url)
        try await validateSandboxAccess(to: url)
    }

    private func validateFileExists(at url: URL) async throws {
        guard fileManager.fileExists(atPath: url.path) else {
            logger.error("File does not exist", metadata: [
                "path": .string(url.path)
            ])
            throw PermissionError.fileNotFound(url)
        }
    }

    private func validateFilePermissions(for url: URL) async throws {
        let resourceValues = try url.resourceValues(forKeys: [
            .isReadableKey,
            .isWritableKey,
            .fileProtectionKey
        ])

        guard resourceValues.isReadable else {
            logger.error("File is not readable", metadata: [
                "path": .string(url.path)
            ])
            throw PermissionError.readAccessDenied(url)
        }

        guard resourceValues.isWritable else {
            logger.error("File is not writable", metadata: [
                "path": .string(url.path)
            ])
            throw PermissionError.writeAccessDenied(url)
        }

        if let protection = resourceValues.fileProtection,
           protection == .complete {
            logger.error("File is encrypted", metadata: [
                "path": .string(url.path)
            ])
            throw PermissionError.fileEncrypted(url)
        }
    }

    private func validateSandboxAccess(to url: URL) async throws {
        let securityScopedURL = try await securityService.resolveBookmark(for: url)

        guard securityScopedURL.startAccessingSecurityScopedResource() else {
            logger.error("Failed to access security-scoped resource", metadata: [
                "path": .string(url.path)
            ])
            throw PermissionError.sandboxAccessDenied(url)
        }

        defer {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }

        try validateSandboxPermissions(for: securityScopedURL)
    }

    private func validateSandboxPermissions(for url: URL) throws {
        let resourceValues = try url.resourceValues(forKeys: [
            .volumeIsReadOnlyKey,
            .volumeSupportsFileCloningKey
        ])

        if let isReadOnly = resourceValues.volumeIsReadOnly,
           isReadOnly {
            logger.error("Volume is read-only", metadata: [
                "path": .string(url.path)
            ])
            throw PermissionError.readOnlyVolume(url)
        }
    }
}
