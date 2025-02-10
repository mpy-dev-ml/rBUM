import XCTest
@testable import Core
@testable import rBUM

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

    func cleanupTemporaryItems(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func generateTestData(size: Int) -> Data {
        var data = Data(capacity: size)
        for byteIndex in 0 ..< size {
            data.append(UInt8(byteIndex % 256))
        }
        return data
    }
}
