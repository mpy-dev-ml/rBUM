import Core
import XCTest
@testable import rBUM

final class FileSearchServiceTests: XCTestCase {
    // MARK: - Properties

    private var sut: FileSearchService!
    private var mockResticService: MockResticCommandService!
    private var logger: LoggerProtocol!
    private var repositoryLock: NSLock!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockResticService = MockResticCommandService()
        logger = TestUtilities.createLogger()
        repositoryLock = NSLock()
        sut = FileSearchService(
            resticService: mockResticService,
            repositoryLock: repositoryLock,
            logger: logger
        )
    }

    override func tearDown() {
        sut = nil
        mockResticService = nil
        logger = nil
        repositoryLock = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testSearchFile_WithValidPattern_ReturnsMatches() async throws {
        // Given
        let pattern = "test.txt"
        let repository = TestRepositoryUtilities.createTestRepository()
        let expectedMatches = [
            ResticFile(path: "/test.txt", size: 100, modTime: Date(), hash: "abc123"),
        ]
        mockResticService.searchFilesResult = expectedMatches

        // When
        let matches = try await sut.searchFile(pattern: pattern, in: repository)

        // Then
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].path, "/test.txt")
        XCTAssertEqual(matches[0].size, 100)
    }

    func testSearchFile_WithInvalidPattern_ThrowsError() async {
        // Given
        let pattern = ""
        let repository = TestRepositoryUtilities.createTestRepository()

        // When/Then
        await XCTAssertThrowsError(try sut.searchFile(pattern: pattern, in: repository)) { error in
            XCTAssertEqual(error as? FileSearchError, .invalidPattern)
        }
    }

    func testSearchFile_WithComplexPattern_ThrowsError() async {
        // Given
        let pattern = "test[0-9]*.txt"
        let repository = TestRepositoryUtilities.createTestRepository()

        // When/Then
        await XCTAssertThrowsError(try sut.searchFile(pattern: pattern, in: repository)) { error in
            XCTAssertEqual(error as? FileSearchError, .invalidPattern)
        }
    }

    func testSearchFile_WhenResticFails_PropagatesError() async {
        // Given
        let pattern = "test.txt"
        let repository = TestRepositoryUtilities.createTestRepository()
        let expectedError = NSError(domain: "test", code: 1)
        mockResticService.searchFilesError = expectedError

        // When/Then
        await XCTAssertThrowsError(try sut.searchFile(pattern: pattern, in: repository)) { error in
            XCTAssertEqual((error as NSError).domain, expectedError.domain)
            XCTAssertEqual((error as NSError).code, expectedError.code)
        }
    }

    func testGetFileVersions_ReturnsVersions() async throws {
        // Given
        let path = "/test.txt"
        let repository = TestRepositoryUtilities.createTestRepository()
        let snapshot = ResticSnapshot(
            id: "123",
            time: Date(),
            paths: [path],
            hostname: "test",
            username: "user"
        )
        mockResticService.listSnapshotsResult = [snapshot]

        // When
        let versions = try await sut.getFileVersions(path: path, in: repository)

        // Then
        XCTAssertEqual(versions.count, 1)
        XCTAssertEqual(versions[0].path, path)
        XCTAssertEqual(versions[0].snapshot.id, snapshot.id)
    }
}

// MARK: - Mocks

private class MockResticCommandService: ResticCommandServiceProtocol {
    var searchFilesResult: [ResticFile] = []
    var searchFilesError: Error?
    var listSnapshotsResult: [ResticSnapshot] = []
    var listSnapshotsError: Error?

    func searchFiles(pattern: String, in repository: Repository) async throws -> [ResticFile] {
        if let error = searchFilesError {
            throw error
        }
        return searchFilesResult
    }

    func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        if let error = listSnapshotsError {
            throw error
        }
        return listSnapshotsResult
    }

    func initRepository(_ repository: Repository) async throws {}
    func createBackup(in repository: Repository, paths: [String]) async throws {}
    func performHealthCheck() async throws -> Bool { true }
}
