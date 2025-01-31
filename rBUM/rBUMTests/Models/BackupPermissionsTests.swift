//
//  BackupPermissionsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupPermissionsTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup permissions with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        
        // When
        let permissions = BackupPermissions(
            id: id,
            repositoryId: repositoryId
        )
        
        // Then
        #expect(permissions.id == id)
        #expect(permissions.repositoryId == repositoryId)
        #expect(!permissions.hasFullDiskAccess)
        #expect(!permissions.hasNotificationAccess)
        #expect(permissions.grantedPaths.isEmpty)
    }
    
    @Test("Initialize backup permissions with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let hasFullDiskAccess = true
        let hasNotificationAccess = true
        let grantedPaths = [
            URL(fileURLWithPath: "/Users/test/Documents"),
            URL(fileURLWithPath: "/Users/test/Pictures")
        ]
        
        // When
        let permissions = BackupPermissions(
            id: id,
            repositoryId: repositoryId,
            hasFullDiskAccess: hasFullDiskAccess,
            hasNotificationAccess: hasNotificationAccess,
            grantedPaths: grantedPaths
        )
        
        // Then
        #expect(permissions.id == id)
        #expect(permissions.repositoryId == repositoryId)
        #expect(permissions.hasFullDiskAccess == hasFullDiskAccess)
        #expect(permissions.hasNotificationAccess == hasNotificationAccess)
        #expect(permissions.grantedPaths == grantedPaths)
    }
    
    // MARK: - Full Disk Access Tests
    
    @Test("Handle full disk access permissions", tags: ["model", "disk"])
    func testFullDiskAccess() throws {
        // Given
        var permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test checking access
        #expect(!permissions.hasFullDiskAccess)
        
        // Test requesting access
        let granted = permissions.requestFullDiskAccess()
        if granted {
            #expect(permissions.hasFullDiskAccess)
        } else {
            #expect(!permissions.hasFullDiskAccess)
        }
    }
    
    // MARK: - Notification Tests
    
    @Test("Handle notification permissions", tags: ["model", "notifications"])
    func testNotificationAccess() throws {
        // Given
        var permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test checking access
        #expect(!permissions.hasNotificationAccess)
        
        // Test requesting access
        let granted = permissions.requestNotificationAccess()
        if granted {
            #expect(permissions.hasNotificationAccess)
        } else {
            #expect(!permissions.hasNotificationAccess)
        }
    }
    
    // MARK: - Path Tests
    
    @Test("Handle path permissions", tags: ["model", "paths"])
    func testPathPermissions() throws {
        // Given
        var permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        let paths = [
            URL(fileURLWithPath: "/Users/test/Documents"),
            URL(fileURLWithPath: "/Users/test/Pictures")
        ]
        
        // Test granting paths
        for path in paths {
            permissions.grantAccess(to: path)
        }
        #expect(permissions.grantedPaths.count == paths.count)
        
        // Test checking access
        for path in paths {
            #expect(permissions.hasAccess(to: path))
        }
        
        // Test revoking paths
        permissions.revokeAccess(to: paths[0])
        #expect(permissions.grantedPaths.count == paths.count - 1)
        #expect(!permissions.hasAccess(to: paths[0]))
        
        // Test clearing paths
        permissions.clearGrantedPaths()
        #expect(permissions.grantedPaths.isEmpty)
    }
    
    // MARK: - Sandbox Tests
    
    @Test("Handle sandbox permissions", tags: ["model", "sandbox"])
    func testSandboxPermissions() throws {
        // Given
        var permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test sandbox status
        #expect(permissions.isSandboxed)
        
        // Test sandbox bookmarks
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        let bookmark = try permissions.createSecurityScopedBookmark(for: path)
        #expect(bookmark != nil)
        
        // Test resolving bookmarks
        if let resolvedPath = permissions.resolveSecurityScopedBookmark(bookmark!) {
            #expect(resolvedPath.path == path.path)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Handle path validation", tags: ["model", "validation"])
    func testPathValidation() throws {
        // Given
        let permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        let testCases = [
            // Valid paths
            "/Users/test/Documents",
            "/Users/test/Pictures",
            "/Applications",
            // Invalid paths
            "",
            "relative/path",
            "/private/var/root"
        ]
        
        for path in testCases {
            let url = URL(fileURLWithPath: path)
            let isValid = path.hasPrefix("/") && 
                         !path.hasPrefix("/private") &&
                         !path.hasPrefix("/System")
            
            #expect(permissions.isValidPath(url) == isValid)
        }
    }
    
    // MARK: - Access Level Tests
    
    @Test("Handle access level checks", tags: ["model", "access"])
    func testAccessLevels() throws {
        // Given
        var permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        let path = URL(fileURLWithPath: "/Users/test/Documents")
        
        // Test read access
        permissions.grantAccess(to: path, level: .readOnly)
        #expect(permissions.hasReadAccess(to: path))
        #expect(!permissions.hasWriteAccess(to: path))
        
        // Test write access
        permissions.grantAccess(to: path, level: .readWrite)
        #expect(permissions.hasReadAccess(to: path))
        #expect(permissions.hasWriteAccess(to: path))
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare permissions for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let permissions1 = BackupPermissions(
            id: UUID(),
            repositoryId: UUID(),
            hasFullDiskAccess: true,
            hasNotificationAccess: true,
            grantedPaths: [URL(fileURLWithPath: "/Users/test/Documents")]
        )
        
        let permissions2 = BackupPermissions(
            id: permissions1.id,
            repositoryId: permissions1.repositoryId,
            hasFullDiskAccess: true,
            hasNotificationAccess: true,
            grantedPaths: [URL(fileURLWithPath: "/Users/test/Documents")]
        )
        
        let permissions3 = BackupPermissions(
            id: UUID(),
            repositoryId: permissions1.repositoryId,
            hasFullDiskAccess: true,
            hasNotificationAccess: true,
            grantedPaths: [URL(fileURLWithPath: "/Users/test/Documents")]
        )
        
        #expect(permissions1 == permissions2)
        #expect(permissions1 != permissions3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup permissions", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic permissions
            BackupPermissions(
                id: UUID(),
                repositoryId: UUID()
            ),
            // Full permissions
            BackupPermissions(
                id: UUID(),
                repositoryId: UUID(),
                hasFullDiskAccess: true,
                hasNotificationAccess: true,
                grantedPaths: [URL(fileURLWithPath: "/Users/test/Documents")]
            )
        ]
        
        for permissions in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(permissions)
            let decoded = try decoder.decode(BackupPermissions.self, from: data)
            
            // Then
            #expect(decoded.id == permissions.id)
            #expect(decoded.repositoryId == permissions.repositoryId)
            #expect(decoded.hasFullDiskAccess == permissions.hasFullDiskAccess)
            #expect(decoded.hasNotificationAccess == permissions.hasNotificationAccess)
            #expect(decoded.grantedPaths == permissions.grantedPaths)
        }
    }
    
    // MARK: - Error Tests
    
    @Test("Handle permission errors", tags: ["model", "error"])
    func testPermissionErrors() throws {
        // Given
        let permissions = BackupPermissions(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test invalid path errors
        let invalidPath = URL(fileURLWithPath: "/private/var/root")
        let error = permissions.grantAccess(to: invalidPath)
        #expect(error == .invalidPath)
        
        // Test access denied errors
        let restrictedPath = URL(fileURLWithPath: "/System")
        let accessError = permissions.grantAccess(to: restrictedPath)
        #expect(accessError == .accessDenied)
    }
}
