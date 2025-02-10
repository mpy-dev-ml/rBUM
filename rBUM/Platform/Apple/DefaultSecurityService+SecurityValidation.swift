import Foundation

/// Extension to DefaultSecurityService handling security validation logic
extension DefaultSecurityService {
    // MARK: - Security Validation

    func validateSecurityPrerequisites(
        url: URL,
        options: SecurityOptions
    ) async throws {
        // Validate URL
        try await validateURL(url)

        // Validate security scope
        try await validateSecurityScope(for: url)

        // Validate options
        try await validateSecurityOptions(options, for: url)
    }

    private func validateURL(_ url: URL) async throws {
        // Check if URL exists
        guard url.isFileURL else {
            throw SecurityError.invalidURL("URL must be a file URL")
        }

        // Check if URL is reachable
        var isReachable = false
        do {
            isReachable = try url.checkResourceIsReachable()
        } catch {
            throw SecurityError.invalidURL("URL is not reachable: \(error.localizedDescription)")
        }

        guard isReachable else {
            throw SecurityError.invalidURL("URL is not reachable")
        }
    }

    private func validateSecurityScope(for url: URL) async throws {
        // Check if URL is in sandbox
        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityError.accessDenied("Cannot access security-scoped resource")
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        // Check if URL is in allowed directories
        guard try await isInAllowedDirectory(url) else {
            throw SecurityError.accessDenied("URL is not in an allowed directory")
        }
    }

    private func validateSecurityOptions(
        _ options: SecurityOptions,
        for url: URL
    ) async throws {
        // Validate read access
        if options.contains(.read) {
            guard try await validateReadAccess(to: url) else {
                throw SecurityError.accessDenied("Read access denied")
            }
        }

        // Validate write access
        if options.contains(.write) {
            guard try await validateWriteAccess(to: url) else {
                throw SecurityError.accessDenied("Write access denied")
            }
        }

        // Validate execute access
        if options.contains(.execute) {
            guard try await validateExecuteAccess(to: url) else {
                throw SecurityError.accessDenied("Execute access denied")
            }
        }
    }

    private func validateReadAccess(to url: URL) async throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [.isReadableKey])
        guard resourceValues.isReadable else {
            return false
        }

        // Check sandbox permissions
        guard try await checkSandboxPermission(.read, for: url) else {
            return false
        }

        return true
    }

    private func validateWriteAccess(to url: URL) async throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [.isWritableKey])
        guard resourceValues.isWritable else {
            return false
        }

        // Check sandbox permissions
        guard try await checkSandboxPermission(.write, for: url) else {
            return false
        }

        return true
    }

    private func validateExecuteAccess(to url: URL) async throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [.isExecutableKey])
        guard resourceValues.isExecutable else {
            return false
        }

        // Check sandbox permissions
        guard try await checkSandboxPermission(.execute, for: url) else {
            return false
        }

        return true
    }

    private func checkSandboxPermission(
        _ permission: SecurityPermission,
        for url: URL
    ) async throws -> Bool {
        // Get sandbox container
        guard let container = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return false
        }

        // Check if URL is in sandbox container
        if url.path.starts(with: container.path) {
            return true
        }

        // Check if URL has security-scoped bookmark
        return try await hasSecurityScopedBookmark(for: url, permission: permission)
    }
}
