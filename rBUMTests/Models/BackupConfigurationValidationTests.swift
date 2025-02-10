import XCTest
@testable import rBUM

final class BackupConfigurationValidationTests: XCTestCase {
    let testSourceURL1 = URL(fileURLWithPath: "/tmp/test1")
    let testSourceURL2 = URL(fileURLWithPath: "/tmp/test2")

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: testSourceURL1, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: testSourceURL2, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testSourceURL1)
        try? FileManager.default.removeItem(at: testSourceURL2)
        super.tearDown()
    }

    func testInvalidName() throws {
        // When creating a configuration with an empty name
        XCTAssertThrowsError(
            try BackupConfiguration(name: "", sources: [testSourceURL1])
        ) { error in
            XCTAssertTrue(error is ConfigurationError)
            XCTAssertTrue(error.localizedDescription.contains("name cannot be empty"))
        }
    }

    func testNoSources() throws {
        // When creating a configuration with no sources
        XCTAssertThrowsError(
            try BackupConfiguration(name: "Test", sources: [])
        ) { error in
            XCTAssertTrue(error is ConfigurationError)
            XCTAssertTrue(error.localizedDescription.contains("must be specified"))
        }
    }

    func testInvalidSource() throws {
        // When creating a configuration with a non-existent source
        let invalidSource = URL(fileURLWithPath: "/nonexistent")
        XCTAssertThrowsError(
            try BackupConfiguration(name: "Test", sources: [invalidSource])
        ) { error in
            XCTAssertTrue(error is ConfigurationError)
            XCTAssertTrue(error.localizedDescription.contains("not accessible"))
        }
    }
}
