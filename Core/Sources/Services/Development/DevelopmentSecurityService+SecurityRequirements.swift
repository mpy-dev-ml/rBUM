//
//  DevelopmentSecurityService+SecurityRequirements.swift
//  rBUM
//
//  First created: 7 February 2025
//  Last updated: 7 February 2025
//

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
                "path": .string(url.path)
            ])
            return false
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            logger.error("File is not readable", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        return true
    }
    
    private func validateSandboxPermissions(for url: URL) async throws -> Bool {
        // Check sandbox entitlements
        let resourceValues = try url.resourceValues(forKeys: [
            .isApplicationKey,
            .isSystemImmutableKey
        ])
        
        // Check if file is in application container
        if let isApplication = resourceValues.isApplication,
           isApplication {
            logger.error("Cannot access application bundle", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Check if file is system protected
        if let isSystemImmutable = resourceValues.isSystemImmutable,
           isSystemImmutable {
            logger.error("Cannot access system protected file", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        return true
    }
    
    private func validateSecurityContext(for url: URL) async throws -> Bool {
        // Check volume properties
        let resourceValues = try url.resourceValues(forKeys: [
            .volumeIsReadOnlyKey,
            .volumeSupportsFileCloningKey,
            .volumeSupportsSymbolicLinksKey
        ])
        
        // Check if volume is read-only
        if let isReadOnly = resourceValues.volumeIsReadOnly,
           isReadOnly {
            logger.error("Volume is read-only", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Check if volume supports required features
        if let supportsCloning = resourceValues.volumeSupportsFileCloning,
           !supportsCloning {
            logger.warning("Volume does not support file cloning", metadata: [
                "path": .string(url.path)
            ])
        }
        
        if let supportsSymlinks = resourceValues.volumeSupportsSymbolicLinks,
           !supportsSymlinks {
            logger.warning("Volume does not support symbolic links", metadata: [
                "path": .string(url.path)
            ])
        }
        
        return true
    }
    
    private func validateWritePermissions(for url: URL) async throws -> Bool {
        // Check if file is writable
        guard fileManager.isWritableFile(atPath: url.path) else {
            logger.error("File is not writable", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Check parent directory permissions
        let parentURL = url.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: parentURL.path) else {
            logger.error("Parent directory is not writable", metadata: [
                "path": .string(parentURL.path)
            ])
            return false
        }
        
        return true
    }
}
