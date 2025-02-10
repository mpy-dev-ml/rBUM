import XCTest
@testable import Core
@testable import rBUM

@MainActor
final class BackupConfigurationViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var testSourceURL: URL!
    private var viewModel: BackupConfigurationViewModel!
    private var mockService: MockBackupConfigurationService!
    private var mockLogger: MockLogger!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary test directories
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        // Create test source directory
        testSourceURL = temporaryDirectory.appendingPathComponent("source", isDirectory: true)
        try FileManager.default.createDirectory(at: testSourceURL, withIntermediateDirectories: true)

        // Set up mocks
        mockService = MockBackupConfigurationService()
        mockLogger = MockLogger()

        // Create view model
        viewModel = BackupConfigurationViewModel(
            configurationService: mockService,
            logger: mockLogger
        )
    }

    override func tearDown() async throws {
        try await super.tearDown()

        // Clean up temporary directory
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        temporaryDirectory = nil
        testSourceURL = nil
        viewModel = nil
        mockService = nil
        mockLogger = nil
    }

    func testLoadConfigurations() async throws {
        // Given some test configurations
        let config = try BackupConfiguration(
            name: "Test Backup",
            sources: [testSourceURL]
        )
        mockService.configurations = [config]

        // When loading configurations
        viewModel.loadConfigurations()

        // Then wait for loading to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // And verify the configurations were loaded
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.configurations.count, 1)
        XCTAssertEqual(viewModel.configurations[0].id, config.id)
    }

    func testCreateConfiguration() async throws {
        // When creating a configuration
        viewModel.createConfiguration(
            name: "Test Backup",
            sources: [testSourceURL]
        )

        // Then wait for creation to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // And verify the configuration was created
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.configurations.count, 1)
        XCTAssertEqual(viewModel.configurations[0].name, "Test Backup")
    }

    func testAccessLifecycle() async throws {
        // Given a test configuration
        let config = try BackupConfiguration(
            name: "Test Backup",
            sources: [testSourceURL]
        )
        mockService.configurations = [config]

        // When starting access
        viewModel.startAccessing(configurationId: config.id)

        // Then wait for access to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // And verify access was started
        XCTAssertNil(viewModel.error)
        XCTAssertTrue(viewModel.configurations[0].isAccessing)

        // When stopping access
        viewModel.stopAccessing(configurationId: config.id)

        // Then wait for access to stop
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // And verify access was stopped
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.configurations[0].isAccessing)
    }
}

// MARK: - Mock Types

private actor MockBackupConfigurationService: BackupConfigurationService {
    var configurations: [BackupConfiguration] = []

    override func loadConfigurations() async throws {
        // No-op, configurations are set directly in tests
    }

    override func getConfigurations() async -> [BackupConfiguration] {
        configurations
    }

    override func createConfiguration(
        name: String,
        description: String?,
        enabled: Bool,
        schedule: BackupSchedule?,
        sources: [URL],
        includeHidden: Bool,
        verifyAfterBackup: Bool,
        repository: Repository?
    ) async throws -> BackupConfiguration {
        let config = try BackupConfiguration(
            name: name,
            description: description,
            enabled: enabled,
            schedule: schedule,
            sources: sources,
            includeHidden: includeHidden,
            verifyAfterBackup: verifyAfterBackup,
            repository: repository
        )
        configurations.append(config)
        return config
    }

    override func startAccessing(configurationId: UUID) async throws {
        guard let index = configurations.firstIndex(where: { $0.id == configurationId }) else {
            throw BackupConfigurationError.configurationNotFound(configurationId)
        }
        var config = configurations[index]
        try config.startAccessing()
        configurations[index] = config
    }

    override func stopAccessing(configurationId: UUID) async {
        guard let index = configurations.firstIndex(where: { $0.id == configurationId }) else {
            return
        }
        var config = configurations[index]
        config.stopAccessing()
        configurations[index] = config
    }
}

private final class MockLogger: LoggerProtocol {
    func debug(_ message: String, privacy: PrivacyLevel) {}
    func info(_ message: String, privacy: PrivacyLevel) {}
    func warning(_ message: String, privacy: PrivacyLevel) {}
    func error(_ message: String, privacy: PrivacyLevel) {}
}
