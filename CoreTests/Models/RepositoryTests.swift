//
//  RepositoryTests.swift
//  CoreTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
@testable import Core

final class RepositoryTests: XCTestCase {
    // MARK: - Properties
    
    private var repository: Repository!
    private var credentials: RepositoryCredentials!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        credentials = RepositoryCredentials(password: "test-password")
        repository = Repository(
            id: UUID(),
            path: URL(fileURLWithPath: "/test/path"),
            name: "Test Repository",
            description: "Test Description",
            credentials: credentials
        )
    }
    
    override func tearDown() async throws {
        repository = nil
        credentials = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    func testRepositoryInitialization() throws {
        XCTAssertNotNil(repository)
        XCTAssertNotNil(repository.id)
        XCTAssertEqual(repository.path.path, "/test/path")
        XCTAssertEqual(repository.name, "Test Repository")
        XCTAssertEqual(repository.description, "Test Description")
        XCTAssertNotNil(repository.credentials)
    }
    
    func testRepositoryEquality() throws {
        let sameRepository = Repository(
            id: repository.id,
            path: repository.path,
            name: repository.name,
            description: repository.description,
            credentials: repository.credentials
        )
        
        XCTAssertEqual(repository, sameRepository)
        
        let differentRepository = Repository(
            id: UUID(),
            path: repository.path,
            name: repository.name,
            description: repository.description,
            credentials: repository.credentials
        )
        
        XCTAssertNotEqual(repository, differentRepository)
    }
    
    func testRepositoryCredentialsEncryption() throws {
        XCTAssertNotEqual(credentials.password, repository.credentials.password)
        XCTAssertTrue(repository.credentials.isEncrypted)
    }
    
    func testRepositoryValidation() throws {
        // Test valid repository
        XCTAssertNoThrow(try repository.validate())
        
        // Test invalid path
        var invalidRepository = repository
        invalidRepository.path = URL(fileURLWithPath: "")
        XCTAssertThrowsError(try invalidRepository.validate()) { error in
            XCTAssertEqual(error as? RepositoryError, .invalidPath)
        }
        
        // Test invalid name
        invalidRepository = repository
        invalidRepository.name = ""
        XCTAssertThrowsError(try invalidRepository.validate()) { error in
            XCTAssertEqual(error as? RepositoryError, .invalidName)
        }
        
        // Test missing credentials
        invalidRepository = repository
        invalidRepository.credentials = nil
        XCTAssertThrowsError(try invalidRepository.validate()) { error in
            XCTAssertEqual(error as? RepositoryError, .missingCredentials)
        }
    }
}
