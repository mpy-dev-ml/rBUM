//
//  FileTestHelpers.swift
//  rBUMTests
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

@testable import Core
@testable import rBUM
import XCTest

extension XCTestCase {
    func createTemporaryFile(
        name: String = UUID().uuidString,
        content: String = "test"
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    func createTemporaryDirectory() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempURL,
            withIntermediateDirectories: true
        )
        return tempURL
    }
}
