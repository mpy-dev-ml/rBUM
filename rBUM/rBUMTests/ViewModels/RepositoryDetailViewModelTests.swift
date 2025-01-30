//
//  RepositoryDetailViewModelTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import XCTest
@testable import rBUM

@MainActor
final class RepositoryDetailViewModelTests: XCTestCase {
    var resticService: TestMocks.MockResticCommandService!
    var credentialsManager: TestMocks.MockCredentialsManager!
    var repository: Repository!
    var sut: RepositoryDetailViewModel!
    
    override func setUpWithError() throws {
        resticService = TestMocks.MockResticCommandService()
        credentialsManager = TestMocks.MockCredentialsManager()
        repository = Repository(name: "Test Repo", path: URL(fileURLWithPath: "/test/path"))
        sut = RepositoryDetailViewModel(
            repository: repository,
            resticService: resticService,
            credentialsManager: credentialsManager
        )
    }
    
    override func tearDownWithError() throws {
        resticService = nil
        credentialsManager = nil
        repository = nil
        sut = nil
    }
    
    func test_checkRepository_success() async throws {
        // Given
        let date = Date()
        
        // When
        await sut.checkRepository()
        
        // Then
        XCTAssertNotNil(sut.lastCheck)
        XCTAssertGreaterThanOrEqual(sut.lastCheck ?? date, date)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
    }
    
    func test_checkRepository_failure() async throws {
        // Given
        resticService.checkError = NSError(domain: "test", code: 1)
        
        // When
        await sut.checkRepository()
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.showError)
        if let error = sut.error as? ResticError {
            XCTAssertEqual(error.localizedDescription, "The operation couldn't be completed. (test error 1.)")
        } else {
            XCTFail("Expected ResticError")
        }
    }
    
    func test_updatePassword_success() async throws {
        // Given
        let newPassword = "new-password"
        
        // When
        try await sut.updatePassword(newPassword)
        
        // Then
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showError)
    }
    
    func test_updatePassword_empty() async throws {
        // Given
        let newPassword = ""
        
        // When/Then
        do {
            try await sut.updatePassword(newPassword)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is ResticError)
            XCTAssertEqual(error.localizedDescription, "Invalid password")
        }
    }
    
    func test_formattedLastCheck_initialState() {
        // Then
        XCTAssertEqual(sut.formattedLastCheck, "Never")
    }
    
    func test_formattedLastCheck_afterCheck() async {
        // When
        await sut.checkRepository()
        
        // Then
        XCTAssertNotEqual(sut.formattedLastCheck, "Never")
        // Note: We can't test the exact formatted string since it depends on the current time
        // but we can verify it's been updated from the initial state
    }
}
