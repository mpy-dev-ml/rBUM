//
//  ResticSnapshotTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

@testable import Core
import Testing

struct ResticSnapshotTests {
    // MARK: - Properties

    let sampleDate = Date(timeIntervalSince1970: 1707469339) // Fixed date for testing
    let sampleTags = ["test", "backup", "important"]
    let samplePaths = ["/path/to/backup", "/another/path"]
    let sampleSize: UInt64 = 1024 * 1024 // 1MB
    let sampleRepoId = "test-repo-id"
    
    var snapshot: ResticSnapshot {
        ResticSnapshot(
            id: "test-snapshot-id",
            time: sampleDate,
            hostname: "test-host",
            tags: sampleTags,
            paths: samplePaths,
            parent: "parent-snapshot-id",
            size: sampleSize,
            repositoryId: sampleRepoId
        )
    }

    // MARK: - Tests

    @Test
    func testSnapshotInitialization() {
        let snapshot = self.snapshot
        
        #expect(snapshot.id == "test-snapshot-id")
        #expect(snapshot.time == sampleDate)
        #expect(snapshot.hostname == "test-host")
        #expect(snapshot.tags == sampleTags)
        #expect(snapshot.paths == samplePaths)
        #expect(snapshot.parent == "parent-snapshot-id")
        #expect(snapshot.size == sampleSize)
        #expect(snapshot.repositoryId == sampleRepoId)
        #expect(snapshot.shortId == "test-sna")
    }

    @Test
    func testSnapshotEquality() {
        let snapshot1 = self.snapshot
        let snapshot2 = ResticSnapshot(
            id: "test-snapshot-id",
            time: sampleDate,
            hostname: "test-host",
            tags: sampleTags,
            paths: samplePaths,
            parent: "parent-snapshot-id",
            size: sampleSize,
            repositoryId: sampleRepoId
        )
        
        #expect(snapshot1 == snapshot2)
        
        // Test inequality
        let differentSnapshot = ResticSnapshot(
            id: "different-id",
            time: sampleDate,
            hostname: "test-host",
            tags: sampleTags,
            paths: samplePaths,
            parent: "parent-snapshot-id",
            size: sampleSize,
            repositoryId: sampleRepoId
        )
        
        #expect(snapshot1 != differentSnapshot)
    }

    @Test
    func testJSONInitialization() throws {
        let json: [String: Any] = [
            "id": "json-test-id",
            "time": "2025-02-09T08:22:19Z",
            "hostname": "json-test-host",
            "tags": ["json", "test"],
            "paths": ["/json/test/path"],
            "parent": "json-parent-id",
            "size": UInt64(2048),
            "repository_id": "json-repo-id"
        ]
        
        let snapshot = try ResticSnapshot(json: json)
        
        #expect(snapshot.id == "json-test-id")
        #expect(snapshot.hostname == "json-test-host")
        #expect(snapshot.tags == ["json", "test"])
        #expect(snapshot.paths == ["/json/test/path"])
        #expect(snapshot.parent == "json-parent-id")
        #expect(snapshot.size == 2048)
        #expect(snapshot.repositoryId == "json-repo-id")
    }

    @Test
    func testJSONInitializationFailure() {
        let invalidJSON: [String: Any] = [
            "id": "test-id",
            // Missing required fields
            "hostname": "test-host"
        ]
        
        #expect(throws: DecodingError.self) {
            _ = try ResticSnapshot(json: invalidJSON)
        }
    }

    @Test
    func testNSCoding() {
        let originalSnapshot = snapshot
        
        // Archive
        let data = try! NSKeyedArchiver.archivedData(
            withRootObject: originalSnapshot,
            requiringSecureCoding: true
        )
        
        // Unarchive
        let unarchivedSnapshot = try! NSKeyedUnarchiver.unarchivedObject(
            of: ResticSnapshot.self,
            from: data
        )
        
        #expect(unarchivedSnapshot != nil)
        #expect(unarchivedSnapshot?.id == originalSnapshot.id)
        #expect(unarchivedSnapshot?.time == originalSnapshot.time)
        #expect(unarchivedSnapshot?.hostname == originalSnapshot.hostname)
        #expect(unarchivedSnapshot?.tags == originalSnapshot.tags)
        #expect(unarchivedSnapshot?.paths == originalSnapshot.paths)
        #expect(unarchivedSnapshot?.parent == originalSnapshot.parent)
        #expect(unarchivedSnapshot?.size == originalSnapshot.size)
        #expect(unarchivedSnapshot?.repositoryId == originalSnapshot.repositoryId)
    }

    @Test
    func testDescription() {
        let snapshot = self.snapshot
        let description = snapshot.description
        
        #expect(description.contains("Snapshot test-sna"))
        #expect(description.contains("Host: test-host"))
        #expect(description.contains("1 MB")) // Size formatting
        #expect(description.contains("Tags: test, backup, important"))
        #expect(description.contains("Paths: /path/to/backup, /another/path"))
    }
}
