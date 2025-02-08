//
//  DefaultSecurityServiceTests+Lifecycle.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import XCTest

extension DefaultSecurityServiceTests {
    func testServiceInitialization() {
        XCTAssertNotNil(service)
        XCTAssertNotNil(mockKeychainService)
        XCTAssertNotNil(mockBookmarkService)
    }
    
    func testServiceShutdown() async throws {
        // Create test repository
        let repository = try createTestRepository(name: "test-repo")
        
        // Start accessing resources
        try await service.startAccessing(repository.url)
        
        // Verify access is granted
        XCTAssertTrue(try await validateRepositoryAccess(repository))
        
        // Shutdown service
        try await service.shutdown()
        
        // Verify access is revoked
        XCTAssertFalse(try await validateRepositoryAccess(repository))
        
        // Clean up
        cleanupTestURLs(repository.url)
    }
    
    func testServiceReset() async throws {
        // Create test repositories
        let repo1 = try createTestRepository(name: "test-repo-1")
        let repo2 = try createTestRepository(name: "test-repo-2")
        
        // Start accessing resources
        try await service.startAccessing(repo1.url)
        try await service.startAccessing(repo2.url)
        
        // Verify access is granted
        XCTAssertTrue(try await validateRepositoryAccess(repo1))
        XCTAssertTrue(try await validateRepositoryAccess(repo2))
        
        // Reset service
        try await service.reset()
        
        // Verify access is revoked
        XCTAssertFalse(try await validateRepositoryAccess(repo1))
        XCTAssertFalse(try await validateRepositoryAccess(repo2))
        
        // Clean up
        cleanupTestURLs(repo1.url, repo2.url)
    }
}
