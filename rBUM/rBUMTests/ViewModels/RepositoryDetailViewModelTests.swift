import Testing
@testable import rBUM

@MainActor
struct RepositoryDetailViewModelTests {
    // MARK: - Test Setup
    
    struct TestContext {
        let resticService: TestMocks.MockResticCommandService
        let credentialsManager: TestMocks.MockCredentialsManager
        let repository: Repository
        let viewModel: RepositoryDetailViewModel
        
        init() {
            self.resticService = TestMocks.MockResticCommandService()
            self.credentialsManager = TestMocks.MockCredentialsManager()
            self.repository = Repository(name: "Test Repo", path: URL(fileURLWithPath: "/test/path"))
            self.viewModel = RepositoryDetailViewModel(
                repository: repository,
                resticService: resticService,
                credentialsManager: credentialsManager
            )
        }
    }
    
    // MARK: - Repository Check Tests
    
    @Test("Check repository successfully", tags: ["check", "model"])
    func testCheckRepositorySuccess() async throws {
        // Given
        let context = TestContext()
        let date = Date()
        
        // When
        await context.viewModel.checkRepository()
        
        // Then
        #expect(context.viewModel.lastCheck != nil)
        #expect((context.viewModel.lastCheck ?? date) >= date)
        #expect(context.viewModel.error == nil)
        #expect(!context.viewModel.showError)
    }
    
    @Test("Handle repository check failure", tags: ["check", "model", "error"])
    func testCheckRepositoryFailure() async throws {
        // Given
        let context = TestContext()
        context.resticService.checkError = NSError(domain: "test", code: 1)
        
        // When
        await context.viewModel.checkRepository()
        
        // Then
        #expect(context.viewModel.error != nil)
        #expect(context.viewModel.showError)
        if let error = context.viewModel.error as? ResticError {
            #expect(error.localizedDescription == "The operation couldn't be completed. (test error 1.)")
        } else {
            #expect(false, "Expected ResticError")
        }
    }
    
    // MARK: - Password Update Tests
    
    @Test("Update repository password successfully", tags: ["password", "model"])
    func testUpdatePasswordSuccess() async throws {
        // Given
        let context = TestContext()
        let newPassword = "new-password"
        
        // When
        try await context.viewModel.updatePassword(newPassword)
        
        // Then
        #expect(context.viewModel.error == nil)
        #expect(!context.viewModel.showError)
    }
    
    @Test("Handle empty password update", tags: ["password", "model", "error"])
    func testUpdatePasswordEmpty() async throws {
        // Given
        let context = TestContext()
        let newPassword = ""
        
        // When/Then
        do {
            try await context.viewModel.updatePassword(newPassword)
            #expect(false, "Expected error to be thrown")
        } catch {
            #expect(error is ResticError)
            #expect(error.localizedDescription == "Invalid password")
        }
    }
    
    // MARK: - Formatting Tests
    
    @Test("Format last check time in initial state", tags: ["formatting", "model"])
    func testFormattedLastCheckInitialState() throws {
        // Given
        let context = TestContext()
        
        // Then
        #expect(context.viewModel.formattedLastCheck == "Never")
    }
    
    @Test("Format last check time after repository check", tags: ["formatting", "model"])
    func testFormattedLastCheckAfterCheck() async throws {
        // Given
        let context = TestContext()
        
        // When
        await context.viewModel.checkRepository()
        
        // Then
        #expect(context.viewModel.formattedLastCheck != "Never", "Last check time should be updated after repository check")
    }
}
