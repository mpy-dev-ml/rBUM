import XCTest
@testable import Core
@testable import rBUM

// MARK: - File Utilities

extension XCTestCase {
    func createTemporaryFile(
        name: String = UUID().uuidString,
        content: String = "test"
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    func createTemporaryDirectory(name: String = UUID().uuidString) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: tempURL,
            withIntermediateDirectories: true
        )
        return tempURL
    }

    func removeTemporaryItem(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Test Data Extensions

extension Data {
    static func testBookmark(for url: URL) -> Data {
        Data("test-bookmark-\(url.lastPathComponent)".utf8)
    }
}
