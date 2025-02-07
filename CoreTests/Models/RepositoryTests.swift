//
//  RepositoryTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

@testable import Core
import XCTest

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

    // MARK: - Equality Tests

    func testRepositoryEquality() {
        let repository1 = Repository(
            id: UUID(),
            name: "Test Repository 1",
            path: "/test/path1",
            created: Date(),
            lastBackup: nil,
            status: .ready
        )
        
        let repository2 = Repository(
            id: repository1.id,
            name: "Test Repository 1",
            path: "/test/path1",
            created: repository1.created,
            lastBackup: nil,
            status: .ready
        )
        
        XCTAssertEqual(repository1, repository2)
    }
    
    func testRepositoryInequality() {
        let repository1 = Repository(
            id: UUID(),
            name: "Test Repository 1",
            path: "/test/path1",
            created: Date(),
            lastBackup: nil,
            status: .ready
        )
        
        let repository2 = Repository(
            id: UUID(),
            name: "Test Repository 2",
            path: "/test/path2",
            created: Date(),
            lastBackup: nil,
            status: .ready
        )
        
        XCTAssertNotEqual(repository1, repository2)
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
