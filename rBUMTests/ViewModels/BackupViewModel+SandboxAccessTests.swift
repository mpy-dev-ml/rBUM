import Testing
@testable import Core
@testable import rBUM

struct BackupViewModelSandboxAccessTests {
    // MARK: - Test Setup

    func makeViewModel() -> BackupViewModel {
        let mockSecurityService = MockSecurityService()
        let mockBookmarkService = MockBookmarkService()
        let mockNotificationService = MockNotificationService()
        let mockLogger = MockLogger()

        return BackupViewModel(
            securityService: mockSecurityService,
            bookmarkService: mockBookmarkService,
            notificationService: mockNotificationService,
            logger: mockLogger
        )
    }

    // MARK: - Source Access Tests

    @Test("validateSourceAccess should succeed when access is already granted")
    func testValidateSourceAccessWithExistingAccess() async throws {
        // Arrange
        let viewModel = makeViewModel()
        let sourceURL = URL(fileURLWithPath: "/test/source")
        viewModel.configuration.sources = [sourceURL]

        let mockSecurity = viewModel.securityService as! MockSecurityService
        mockSecurity.validateAccessResult = true

        // Act
        try await viewModel.validateSourceAccess()

        // Assert
        #expect(mockSecurity.validateAccessCalled)
        #expect(mockSecurity.lastValidatedURL == sourceURL)
    }

    @Test("validateSourceAccess should restore access from bookmark when validation fails")
    func testValidateSourceAccessWithBookmarkRestoration() async throws {
        // Arrange
        let viewModel = makeViewModel()
        let sourceURL = URL(fileURLWithPath: "/test/source")
        viewModel.configuration.sources = [sourceURL]

        let mockSecurity = viewModel.securityService as! MockSecurityService
        mockSecurity.validateAccessResult = false

        let mockBookmark = viewModel.bookmarkService as! MockBookmarkService
        mockBookmark.getBookmarkResult = Data()

        // Act
        try await viewModel.validateSourceAccess()

        // Assert
        #expect(mockSecurity.validateAccessCalled)
        #expect(mockBookmark.getBookmarkCalled)
        #expect(mockBookmark.startAccessingCalled)
    }

    @Test("validateSourceAccess should request new access when no bookmark exists")
    func testValidateSourceAccessWithNewAccess() async throws {
        // Arrange
        let viewModel = makeViewModel()
        let sourceURL = URL(fileURLWithPath: "/test/source")
        viewModel.configuration.sources = [sourceURL]

        let mockSecurity = viewModel.securityService as! MockSecurityService
        mockSecurity.validateAccessResult = false
        mockSecurity.requestAccessResult = true

        let mockBookmark = viewModel.bookmarkService as! MockBookmarkService
        mockBookmark.getBookmarkResult = nil

        // Act
        try await viewModel.validateSourceAccess()

        // Assert
        #expect(mockSecurity.requestAccessCalled)
        #expect(mockBookmark.createBookmarkCalled)
    }

    @Test("validateSourceAccess should throw when access is denied")
    func testValidateSourceAccessWithDeniedAccess() async throws {
        // Arrange
        let viewModel = makeViewModel()
        let sourceURL = URL(fileURLWithPath: "/test/source")
        viewModel.configuration.sources = [sourceURL]

        let mockSecurity = viewModel.securityService as! MockSecurityService
        mockSecurity.validateAccessResult = false
        mockSecurity.requestAccessResult = false

        // Act/Assert
        await #expect(throws: SandboxError.self) {
            try await viewModel.validateSourceAccess()
        }
    }

    // MARK: - Repository Access Tests

    @Test("validateRepositoryAccess should succeed when access is already granted")
    func testValidateRepositoryAccessWithExistingAccess() async throws {
        // Arrange
        let viewModel = makeViewModel()
        let repoURL = URL(fileURLWithPath: "/test/repo")
        viewModel.configuration.repository = Repository(url: repoURL)

        let mockSecurity = viewModel.securityService as! MockSecurityService
        mockSecurity.validateAccessResult = true

        // Act
        try await viewModel.validateRepositoryAccess()

        // Assert
        #expect(mockSecurity.validateAccessCalled)
        #expect(mockSecurity.lastValidatedURL == repoURL)
    }

    @Test("validateRepositoryAccess should throw when repository is not configured")
    func testValidateRepositoryAccessWithNoRepository() async throws {
        // Arrange
        let viewModel = makeViewModel()
        viewModel.configuration.repository = nil

        // Act/Assert
        await #expect(throws: SandboxError.self) {
            try await viewModel.validateRepositoryAccess()
        }
    }

    // MARK: - Cleanup Tests

    @Test("cleanupAccess should stop accessing all resources")
    func testCleanupAccess() async throws {
        // Arrange
        let viewModel = makeViewModel()
        let sourceURL = URL(fileURLWithPath: "/test/source")
        let repoURL = URL(fileURLWithPath: "/test/repo")

        viewModel.configuration.sources = [sourceURL]
        viewModel.configuration.repository = Repository(url: repoURL)

        let mockBookmark = viewModel.bookmarkService as! MockBookmarkService

        // Act
        viewModel.cleanupAccess()

        // Assert
        try await Task.sleep(nanoseconds: 100_000_000) // Wait for async cleanup
        #expect(mockBookmark.stopAccessingCalled)
        #expect(mockBookmark.stopAccessingURLs.contains(sourceURL))
        #expect(mockBookmark.stopAccessingURLs.contains(repoURL))
    }
}
