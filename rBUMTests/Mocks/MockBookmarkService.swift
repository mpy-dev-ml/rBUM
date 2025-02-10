import Foundation
@testable import Core
@testable import rBUM

final class MockBookmarkService: BookmarkServiceProtocol {
    // MARK: - Test Properties

    var getBookmarkCalled = false
    var getBookmarkResult: Data?
    var lastGetBookmarkURL: URL?

    var createBookmarkCalled = false
    var createBookmarkResult = Data()
    var lastCreateBookmarkURL: URL?

    var startAccessingCalled = false
    var startAccessingURLs: [URL] = []

    var stopAccessingCalled = false
    var stopAccessingURLs: [URL] = []

    // MARK: - BookmarkServiceProtocol Implementation

    func getBookmark(for url: URL) async throws -> Data? {
        getBookmarkCalled = true
        lastGetBookmarkURL = url
        return getBookmarkResult
    }

    func createBookmark(for url: URL) async throws -> Data {
        createBookmarkCalled = true
        lastCreateBookmarkURL = url
        return createBookmarkResult
    }

    func startAccessing(_ url: URL, with bookmark: Data) async throws {
        startAccessingCalled = true
        startAccessingURLs.append(url)
    }

    func stopAccessing(_ url: URL) async throws {
        stopAccessingCalled = true
        stopAccessingURLs.append(url)
    }

    func validateBookmark(_ bookmark: Data) async throws -> Bool {
        true
    }
}
