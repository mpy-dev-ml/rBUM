import XCTest
@testable import Core
@testable import rBUM

// MARK: - Test Helpers

extension XCTestCase {
    func createTemporaryFile(name: String = UUID().uuidString, content: String = "test") throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    func cleanupTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func createTemporaryDirectory(name: String = UUID().uuidString) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        return tempURL
    }

    func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Test Data Generation

extension XCTestCase {
    static func generateTestData(size: Int = 1024) -> Data {
        var data = Data(count: size)
        for index in 0 ..< size {
            data[index] = UInt8.random(in: 0 ... 255)
        }
        return data
    }

    static func generateTestFile(name: String, size: Int = 1024) throws -> URL {
        let data = generateTestData(size: size)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
