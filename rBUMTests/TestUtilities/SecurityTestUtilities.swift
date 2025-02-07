//
//  SecurityTestUtilities.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
@testable import rBUM
import XCTest

// MARK: - Test URL Extensions
extension URL {
    static func temporaryTestDirectory(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    static func temporaryTestFile(name: String, content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Test Data Extensions
extension Data {
    static func testBookmark(for url: URL) -> Data {
        return "test-bookmark-\(url.lastPathComponent)".data(using: .utf8)!
    }
}

// MARK: - Test Error Types
enum TestError: Error {
    case testFailure(String)
}

// MARK: - XCTestCase Extensions
extension XCTestCase {
    func cleanupTestURLs(_ urls: URL...) {
        urls.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func verifyLogMessages(_ logger: MockLogger, contains messages: String...) {
        messages.forEach { message in
            XCTAssertTrue(logger.containsMessage(message), "Log should contain message: \(message)")
        }
    }
}
