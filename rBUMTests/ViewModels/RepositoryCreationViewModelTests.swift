//
//  RepositoryCreationViewModelTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

@testable import Core
@testable import rBUM
import XCTest

@MainActor
final class RepositoryCreationViewModelTests: XCTestCase {
    // MARK: - Properties
    
    private var viewModel: RepositoryCreationViewModel!
    private var repositoryService: MockRepositoryService!
    private var securityService: MockSecurityService!
    private var logger: TestLogger!
    private var notificationCenter: TestNotificationCenter!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        logger = TestLogger()
        notificationCenter = TestNotificationCenter()
        repositoryService = MockRepositoryService()
        securityService = MockSecurityService()
        
        viewModel = RepositoryCreationViewModel(
            repositoryService: repositoryService,
            securityService: securityService,
            logger: logger,
            notificationCenter: notificationCenter
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        repositoryService = nil
        securityService = nil
        logger = nil
        notificationCenter = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    func testInitialState() throws {
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.name, "")
        XCTAssertEqual(viewModel.description, "")
        XCTAssertNil(viewModel.selectedPath)
        XCTAssertEqual(viewModel.password, "")
        XCTAssertEqual(viewModel.confirmPassword, "")
    }
    
    func testValidation() throws {
        // Test empty name
        viewModel.name = ""
        viewModel.description = "Test"
        viewModel.selectedPath = URL(fileURLWithPath: "/test")
        viewModel.password = "password"
        viewModel.confirmPassword = "password"
        
        XCTAssertFalse(viewModel.isValid)
        
        // Test empty path
        viewModel.name = "Test"
        viewModel.selectedPath = nil
        
        XCTAssertFalse(viewModel.isValid)
        
        // Test password mismatch
        viewModel.selectedPath = URL(fileURLWithPath: "/test")
        viewModel.password = "password1"
        viewModel.confirmPassword = "password2"
        
        XCTAssertFalse(viewModel.isValid)
        
        // Test valid state
        viewModel.password = "password"
        viewModel.confirmPassword = "password"
        
        XCTAssertTrue(viewModel.isValid)
    }
    
    func testSuccessfulRepositoryCreation() async throws {
        // Setup valid input
        viewModel.name = "Test Repository"
        viewModel.description = "Test Description"
        viewModel.selectedPath = URL(fileURLWithPath: "/test/repo")
        viewModel.password = "password123"
        viewModel.confirmPassword = "password123"
        
        // Configure mock service
        let expectedRepository = Repository(
            id: UUID(),
            path: viewModel.selectedPath!,
            name: viewModel.name,
            description: viewModel.description,
            credentials: RepositoryCredentials(password: viewModel.password)
        )
        repositoryService.mockRepository = expectedRepository
        
        // Attempt creation
        await viewModel.createRepository()
        
        // Verify state
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.error)
        
        // Verify service calls
        XCTAssertTrue(repositoryService.createRepositoryCalled)
        XCTAssertTrue(securityService.secureCredentialsCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Creating repository") })
        XCTAssertTrue(logger.messages.contains { $0.contains("Repository created successfully") })
        
        // Verify notifications
        XCTAssertTrue(notificationCenter.postedNotifications.contains { $0.name == .repositoryCreated })
    }
    
    func testFailedRepositoryCreation() async throws {
        // Setup valid input
        viewModel.name = "Test Repository"
        viewModel.description = "Test Description"
        viewModel.selectedPath = URL(fileURLWithPath: "/test/repo")
        viewModel.password = "password123"
        viewModel.confirmPassword = "password123"
        
        // Configure mock service to fail
        repositoryService.shouldFail = true
        
        // Attempt creation
        await viewModel.createRepository()
        
        // Verify error state
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.error)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Failed to create repository") })
        
        // Verify notifications
        XCTAssertTrue(notificationCenter.postedNotifications.contains { $0.name == .repositoryCreationFailed })
    }
    
    func testPathSelection() async throws {
        let testURL = URL(fileURLWithPath: "/test/path")
        
        // Configure security service
        securityService.mockBookmarkData = Data()
        
        // Select path
        await viewModel.selectPath(testURL)
        
        // Verify path selection
        XCTAssertEqual(viewModel.selectedPath, testURL)
        
        // Verify security service calls
        XCTAssertTrue(securityService.createBookmarkCalled)
        
        // Verify logging
        XCTAssertTrue(logger.messages.contains { $0.contains("Selected repository path") })
    }
    
    func testConcurrentCreation() async throws {
        // Setup valid input
        viewModel.name = "Test Repository"
        viewModel.description = "Test Description"
        viewModel.selectedPath = URL(fileURLWithPath: "/test/repo")
        viewModel.password = "password123"
        viewModel.confirmPassword = "password123"
        
        // Attempt multiple concurrent creations
        async let creation1 = viewModel.createRepository()
        async let creation2 = viewModel.createRepository()
        
        // Wait for both to complete
        _ = await [creation1, creation2]
        
        // Verify only one creation was processed
        XCTAssertEqual(repositoryService.createRepositoryCallCount, 1)
    }
}

// MARK: - Test Helpers

private final class MockRepositoryService: RepositoryServiceProtocol {
    var createRepositoryCalled = false
    var createRepositoryCallCount = 0
    var mockRepository: Repository?
    var shouldFail = false
    
    func createRepository(name: String, description: String, path: URL, credentials: RepositoryCredentials) async throws -> Repository {
        createRepositoryCalled = true
        createRepositoryCallCount += 1
        
        if shouldFail {
            throw RepositoryError.creationFailed
        }
        
        return mockRepository ?? Repository(
            id: UUID(),
            path: path,
            name: name,
            description: description,
            credentials: credentials
        )
    }
}

private final class MockSecurityService: SecurityServiceProtocol {
    var createBookmarkCalled = false
    var secureCredentialsCalled = false
    var mockBookmarkData: Data?
    
    func createBookmark(for url: URL) throws -> Data {
        createBookmarkCalled = true
        return mockBookmarkData ?? Data()
    }
    
    func resolveBookmark(_ data: Data) throws -> URL {
        return URL(fileURLWithPath: "/test")
    }
    
    func secureCredentials(_ credentials: RepositoryCredentials) throws -> RepositoryCredentials {
        secureCredentialsCalled = true
        return credentials
    }
}

private extension Notification.Name {
    static let repositoryCreated = Notification.Name("RepositoryCreated")
    static let repositoryCreationFailed = Notification.Name("RepositoryCreationFailed")
}
