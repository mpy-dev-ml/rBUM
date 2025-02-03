//
//  ResticSnapshotTests.swift
//  CoreTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
@testable import Core

final class ResticSnapshotTests: XCTestCase {
    // MARK: - Properties
    
    private var snapshot: ResticSnapshot!
    private var sampleDate: Date!
    private var sampleTags: [String]!
    private var samplePaths: [String]!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        sampleDate = Date()
        sampleTags = ["test", "backup", "important"]
        samplePaths = ["/path/to/backup", "/another/path"]
        
        snapshot = ResticSnapshot(
            id: "test-snapshot-id",
            time: sampleDate,
            hostname: "test-host",
            username: "test-user",
            paths: samplePaths,
            tags: sampleTags,
            sizeInBytes: 1024,
            fileCount: 42
        )
    }
    
    override func tearDown() async throws {
        snapshot = nil
        sampleDate = nil
        sampleTags = nil
        samplePaths = nil
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    func testSnapshotInitialization() throws {
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot.id, "test-snapshot-id")
        XCTAssertEqual(snapshot.time, sampleDate)
        XCTAssertEqual(snapshot.hostname, "test-host")
        XCTAssertEqual(snapshot.username, "test-user")
        XCTAssertEqual(snapshot.paths, samplePaths)
        XCTAssertEqual(snapshot.tags, sampleTags)
        XCTAssertEqual(snapshot.sizeInBytes, 1024)
        XCTAssertEqual(snapshot.fileCount, 42)
    }
    
    func testSnapshotEquality() throws {
        let sameSnapshot = ResticSnapshot(
            id: snapshot.id,
            time: snapshot.time,
            hostname: snapshot.hostname,
            username: snapshot.username,
            paths: snapshot.paths,
            tags: snapshot.tags,
            sizeInBytes: snapshot.sizeInBytes,
            fileCount: snapshot.fileCount
        )
        
        XCTAssertEqual(snapshot, sameSnapshot)
        
        let differentSnapshot = ResticSnapshot(
            id: "different-id",
            time: snapshot.time,
            hostname: snapshot.hostname,
            username: snapshot.username,
            paths: snapshot.paths,
            tags: snapshot.tags,
            sizeInBytes: snapshot.sizeInBytes,
            fileCount: snapshot.fileCount
        )
        
        XCTAssertNotEqual(snapshot, differentSnapshot)
    }
    
    func testSnapshotValidation() throws {
        // Test valid snapshot
        XCTAssertNoThrow(try snapshot.validate())
        
        // Test invalid ID
        var invalidSnapshot = snapshot
        invalidSnapshot.id = ""
        XCTAssertThrowsError(try invalidSnapshot.validate()) { error in
            XCTAssertEqual(error as? SnapshotError, .invalidId)
        }
        
        // Test invalid time
        invalidSnapshot = snapshot
        invalidSnapshot.time = Date(timeIntervalSince1970: -1)
        XCTAssertThrowsError(try invalidSnapshot.validate()) { error in
            XCTAssertEqual(error as? SnapshotError, .invalidTime)
        }
        
        // Test empty paths
        invalidSnapshot = snapshot
        invalidSnapshot.paths = []
        XCTAssertThrowsError(try invalidSnapshot.validate()) { error in
            XCTAssertEqual(error as? SnapshotError, .emptyPaths)
        }
    }
    
    func testSnapshotSerialization() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding
        let encodedData = try encoder.encode(snapshot)
        XCTAssertNotNil(encodedData)
        
        // Test decoding
        let decodedSnapshot = try decoder.decode(ResticSnapshot.self, from: encodedData)
        XCTAssertEqual(snapshot, decodedSnapshot)
    }
    
    func testSnapshotMetadata() throws {
        let metadata = snapshot.metadata
        
        XCTAssertEqual(metadata["id"] as? String, snapshot.id)
        XCTAssertEqual(metadata["hostname"] as? String, snapshot.hostname)
        XCTAssertEqual(metadata["username"] as? String, snapshot.username)
        XCTAssertEqual(metadata["size"] as? Int, snapshot.sizeInBytes)
        XCTAssertEqual(metadata["fileCount"] as? Int, snapshot.fileCount)
        XCTAssertEqual(metadata["tags"] as? [String], snapshot.tags)
    }
    
    func testSnapshotFormatting() throws {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        let formattedSnapshot = snapshot.formattedDescription
        
        XCTAssertTrue(formattedSnapshot.contains(snapshot.id))
        XCTAssertTrue(formattedSnapshot.contains(formatter.string(from: snapshot.time)))
        XCTAssertTrue(formattedSnapshot.contains(snapshot.hostname))
        XCTAssertTrue(formattedSnapshot.contains("\(snapshot.fileCount) files"))
        XCTAssertTrue(formattedSnapshot.contains(ByteCountFormatter.string(fromByteCount: Int64(snapshot.sizeInBytes), countStyle: .file)))
    }
}
