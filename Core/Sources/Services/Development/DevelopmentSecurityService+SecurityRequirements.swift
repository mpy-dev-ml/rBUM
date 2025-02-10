import Core
import Foundation
import os.log

@available(macOS 13.0, *)
extension DevelopmentSecurityService {
    func validateSecurityRequirements(for url: URL) async throws -> Bool {
        try await validateFileSystemAccess(for: url) &&
        try await validateSandboxPermissions(for: url) &&
        try await validateSecurityContext(for: url)
    }

    func validateWriteSecurityRequirements(for url: URL) async throws -> Bool {
        try await validateFileSystemAccess(for: url) &&
        try await validateSandboxPermissions(for: url) &&
        try await validateSecurityContext(for: url) &&
        try await validateWritePermissions(for: url)
    }

    private func validateFileSystemAccess(for url: URL) async throws -> Bool {
        // Check basic file existence and permissions
        guard fileManager.fileExists(atPath: url.path) else {
            logger.error("File does not exist", metadata: [
                "path": .string(url.path),
            ])
            return false
        }

        // Check if file is readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            logger.error("File is not readable", metadata: [
                "path": .string(url.path),
            ])
            return false
        }

        return true
    }

    private func validateSandboxPermissions(for url: URL) async throws -> Bool {
        // Validate sandbox permissions
        do {
            try await securityService.validateSandboxAccess(to: url)
            return true
        } catch {
            logger.error("Sandbox permission validation failed", metadata: [
                "path": .string(url.path),
                "error": .string(error.localizedDescription),
            ])
            return false
        }
    }

    private func validateSecurityContext(for url: URL) async throws -> Bool {
        // Validate security context
        do {
            try await securityService.validateSecurityContext(for: url)
            return true
        } catch {
            logger.error("Security context validation failed", metadata: [
                "path": .string(url.path),
                "error": .string(error.localizedDescription),
            ])
            return false
        }
    }

    private func validateWritePermissions(for url: URL) async throws -> Bool {
        // Check write permissions
        guard fileManager.isWritableFile(atPath: url.path) else {
            logger.error("File is not writable", metadata: [
                "path": .string(url.path),
            ])
            return false
        }

        return true
    }
}
