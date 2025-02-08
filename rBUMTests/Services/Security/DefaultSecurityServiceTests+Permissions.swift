//
//  DefaultSecurityServiceTests+Permissions.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import XCTest

extension DefaultSecurityServiceTests {
    func testRequestAccess() async throws {
        // Create test repository
        let repository = try createTestRepository(name: "test-repo")
        
        // Request access
        try await service.requestAccess(to: repository.url)
        
        // Verify access is granted
        XCTAssertTrue(try await validateRepositoryAccess(repository))
        
        // Clean up
        cleanupTestURLs(repository.url)
    }
    
    func testStartAccessingURL() async throws {
        // Create test repository
        let repository = try createTestRepository(name: "test-repo")
        
        // Start accessing
        try await service.startAccessing(repository.url)
        
        // Verify access is granted
        XCTAssertTrue(try await validateRepositoryAccess(repository))
        
        // Clean up
        cleanupTestURLs(repository.url)
    }
    
    func testStopAccessingURL() async throws {
        // Create test repository
        let repository = try createTestRepository(name: "test-repo")
        
        // Start accessing
        try await service.startAccessing(repository.url)
        
        // Verify access is granted
        XCTAssertTrue(try await validateRepositoryAccess(repository))
        
        // Stop accessing
        try await service.stopAccessing(repository.url)
        
        // Verify access is revoked
        XCTAssertFalse(try await validateRepositoryAccess(repository))
        
        // Clean up
        cleanupTestURLs(repository.url)
    }
    
    func testMultipleAccessRequests() async throws {
        // Create test repositories
        let repo1 = try createTestRepository(name: "test-repo-1")
        let repo2 = try createTestRepository(name: "test-repo-2")
        
        // Request access to both
        try await service.requestAccess(to: repo1.url)
        try await service.requestAccess(to: repo2.url)
        
        // Verify access is granted to both
        XCTAssertTrue(try await validateRepositoryAccess(repo1))
        XCTAssertTrue(try await validateRepositoryAccess(repo2))
        
        // Clean up
        cleanupTestURLs(repo1.url, repo2.url)
    }
}
