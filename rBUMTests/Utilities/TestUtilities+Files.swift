@testable import Core
@testable import rBUM
import XCTest

// MARK: - File Test Utilities

extension XCTestCase {
    func createTemporaryFile(name: String = UUID().uuidString, content: String = "test") throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    func createTemporaryDirectory(name: String = UUID().uuidString) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        return tempURL
    }

    func cleanupTemporaryFiles(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func verifyFileExists(at url: URL, message: String? = nil) {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            message ?? "File should exist at \(url.path)"
        )
    }

    func verifyFileDoesNotExist(at url: URL, message: String? = nil) {
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: url.path),
            message ?? "File should not exist at \(url.path)"
        )
    }

    func verifyDirectoryExists(at url: URL, message: String? = nil) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        XCTAssertTrue(exists && isDirectory.boolValue, message ?? "Directory should exist at \(url.path)")
    }

    func verifyDirectoryDoesNotExist(at url: URL, message: String? = nil) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        XCTAssertFalse(exists && isDirectory.boolValue, message ?? "Directory should not exist at \(url.path)")
    }
}
