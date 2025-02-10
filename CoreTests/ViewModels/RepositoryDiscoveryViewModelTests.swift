import Foundation
import Testing
@testable import Core

struct RepositoryDiscoveryViewModelTests {
    // MARK: - Properties

    let testURL = URL(filePath: "/test/path")
    let mockRepository = DiscoveredRepository(
        id: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
        url: URL(filePath: "/test/path"),
        type: .local,
        discoveredAt: Date(timeIntervalSince1970: 1_707_500_000),
        isVerified: false,
        metadata: RepositoryMetadata(
            size: 1024 * 1024,
            lastModified: Date(timeIntervalSince1970: 1_707_400_000),
            snapshotCount: 5
        )
    )

    // MARK: - Scanning Tests

    @Test
    func testStartScan_Success() async throws {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        service.scanLocationResult = [mockRepository]
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)

        // Act
        viewModel.startScan(at: testURL, recursive: true)
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)

        // Assert
        #expect(viewModel.discoveredRepositories == [mockRepository])
        #expect(viewModel.scanningStatus == .completed(foundCount: 1))
        #expect(viewModel.error == nil)
        #expect(service.scanLocationCalled)
        #expect(service.scanLocationURL == testURL)
        #expect(service.scanLocationRecursive == true)
    }

    @Test
    func testStartScan_Failure() async throws {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        service.scanLocationError = RepositoryDiscoveryError.accessDenied(testURL)
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)

        // Act
        viewModel.startScan(at: testURL, recursive: true)
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)

        // Assert
        #expect(viewModel.discoveredRepositories.isEmpty)
        #expect(viewModel.scanningStatus == .idle)
        #expect(viewModel.error as? RepositoryDiscoveryError == .accessDenied(testURL))
    }

    @Test
    func testCancelScan() async throws {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)

        // Act
        viewModel.startScan(at: testURL, recursive: true)
        viewModel.cancelScan()

        // Assert
        #expect(viewModel.scanningStatus == .idle)
        #expect(service.cancelDiscoveryCalled)
    }

    // MARK: - Repository Management Tests

    @Test
    func testAddRepository_Success() async throws {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        service.verifyRepositoryResult = true
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)

        // Act
        try await viewModel.addRepository(mockRepository)

        // Assert
        #expect(service.verifyRepositoryCalled)
        #expect(service.verifyRepositoryInput == mockRepository)
        #expect(service.indexRepositoryCalled)
        #expect(service.indexRepositoryInput == mockRepository)
    }

    @Test
    func testAddRepository_VerificationFailure() async throws {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        service.verifyRepositoryResult = false
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)

        // Act & Assert
        await #expect(throws: RepositoryDiscoveryError.invalidRepository(mockRepository.url)) {
            try await viewModel.addRepository(mockRepository)
        }

        #expect(service.verifyRepositoryCalled)
        #expect(!service.indexRepositoryCalled)
    }

    @Test
    func testAddRepository_IndexingFailure() async throws {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        service.verifyRepositoryResult = true
        service.indexRepositoryError = RepositoryDiscoveryError.discoveryFailed("Indexing failed")
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)

        // Act & Assert
        await #expect(throws: RepositoryDiscoveryError.discoveryFailed("Indexing failed")) {
            try await viewModel.addRepository(mockRepository)
        }

        #expect(service.verifyRepositoryCalled)
        #expect(service.indexRepositoryCalled)
    }

    @Test
    func testClearError() {
        // Arrange
        let service = MockRepositoryDiscoveryService()
        let viewModel = RepositoryDiscoveryViewModel(discoveryService: service)
        viewModel.error = .accessDenied(testURL)

        // Act
        viewModel.clearError()

        // Assert
        #expect(viewModel.error == nil)
    }
}

// MARK: - Mock Service

private final class MockRepositoryDiscoveryService: RepositoryDiscoveryProtocol {
    // MARK: - Properties

    var scanLocationCalled = false
    var scanLocationURL: URL?
    var scanLocationRecursive: Bool?
    var scanLocationResult: [DiscoveredRepository] = []
    var scanLocationError: Error?

    var verifyRepositoryCalled = false
    var verifyRepositoryInput: DiscoveredRepository?
    var verifyRepositoryResult = false
    var verifyRepositoryError: Error?

    var indexRepositoryCalled = false
    var indexRepositoryInput: DiscoveredRepository?
    var indexRepositoryError: Error?

    var cancelDiscoveryCalled = false

    // MARK: - Protocol Implementation

    func scanLocation(_ url: URL, recursive: Bool) async throws -> [DiscoveredRepository] {
        scanLocationCalled = true
        scanLocationURL = url
        scanLocationRecursive = recursive

        if let error = scanLocationError {
            throw error
        }
        return scanLocationResult
    }

    func verifyRepository(_ repository: DiscoveredRepository) async throws -> Bool {
        verifyRepositoryCalled = true
        verifyRepositoryInput = repository

        if let error = verifyRepositoryError {
            throw error
        }
        return verifyRepositoryResult
    }

    func indexRepository(_ repository: DiscoveredRepository) async throws {
        indexRepositoryCalled = true
        indexRepositoryInput = repository

        if let error = indexRepositoryError {
            throw error
        }
    }

    func cancelDiscovery() {
        cancelDiscoveryCalled = true
    }
}
