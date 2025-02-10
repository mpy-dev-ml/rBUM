import XCTest
@testable import rBUM

final class BackupConfigurationTests: XCTestCase {
    let testSourceURL1 = URL(fileURLWithPath: "/tmp/test1")
    let testSourceURL2 = URL(fileURLWithPath: "/tmp/test2")

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(
            at: testSourceURL1,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: testSourceURL2,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testSourceURL1)
        try? FileManager.default.removeItem(at: testSourceURL2)
        super.tearDown()
    }

    func testValidConfiguration() throws {
        // Given
        let config = try BackupConfiguration(
            name: "Test Backup",
            sources: [testSourceURL1]
        )

        // Then
        XCTAssertEqual(config.name, "Test Backup")
        XCTAssertEqual(config.sources.count, 1)
        XCTAssertEqual(config.sources.first, testSourceURL1)
    }

    func testMultipleSources() throws {
        // Given
        let config = try BackupConfiguration(
            name: "Test Backup",
            sources: [testSourceURL1, testSourceURL2]
        )

        // Then
        XCTAssertEqual(config.sources.count, 2)
        XCTAssertTrue(config.sources.contains(testSourceURL1))
        XCTAssertTrue(config.sources.contains(testSourceURL2))
    }

    func testEmptyExclusions() throws {
        // Given
        let config = try BackupConfiguration(
            name: "Test Backup",
            sources: [testSourceURL1]
        )

        // Then
        XCTAssertTrue(config.exclusionPatterns.isEmpty)
        XCTAssertTrue(config.exclusionPatternGroups.isEmpty)

        // And no paths should be excluded
        let (excluded, reason) = config.shouldExclude(path: "test.txt")
        XCTAssertFalse(excluded)
        XCTAssertNil(reason)
    }
}
