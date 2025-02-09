import Core
import Foundation
import ResticService
import Testing
import XCTest

final class RepositoryDiscoveryPerformanceTests: XCTestCase {
    // MARK: - Properties
    
    private var testDirectory: URL!
    private var service: ResticService!
    private var viewModel: RepositoryDiscoveryViewModel!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test directory
        testDirectory = URL(filePath: "/tmp/rbum_performance_test")
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
        
        service = ResticService()
        viewModel = RepositoryDiscoveryViewModel(discoveryService: service)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        try? FileManager.default.removeItem(at: testDirectory)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRepository(at url: URL, snapshotCount: Int, filesPerSnapshot: Int) throws {
        try FileManager.default.createDirectory(
            at: url.appending(path: "data"),
            withIntermediateDirectories: true
        )
        
        try """
        {
          "version": 1,
          "id": "\(UUID().uuidString)",
          "created": "\(Date().ISO8601Format())",
          "repository": {
            "version": 1,
            "compression": "auto"
          }
        }
        """.write(
            to: url.appending(path: "config"),
            atomically: true,
            encoding: .utf8
        )
        
        // Create snapshots directory
        let snapshotsDir = url.appending(path: "snapshots")
        try FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
        
        // Create test snapshots
        for snapshotIndex in 0..<snapshotCount {
            let snapshotId = "snapshot-\(snapshotIndex)"
            let snapshotDir = snapshotsDir.appending(path: snapshotId)
            try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
            
            // Create test files
            for fileIndex in 0..<filesPerSnapshot {
                let fileURL = snapshotDir.appending(path: "file-\(fileIndex).txt")
                try "Test content for file \(fileIndex) in snapshot \(snapshotIndex)".write(
                    to: fileURL,
                    atomically: true,
                    encoding: .utf8
                )
            }
            
            // Create snapshot metadata
            try """
            {
                "id": "\(snapshotId)",
                "time": "\(Date().ISO8601Format())",
                "paths": ["\(snapshotDir.path)"]
            }
            """.write(
                to: snapshotsDir.appending(path: "\(snapshotId).json"),
                atomically: true,
                encoding: .utf8
            )
        }
    }
    
    // MARK: - Performance Tests
    
    func testDiscoveryPerformance_SmallRepository() throws {
        let repoURL = testDirectory.appending(path: "small_repo")
        try createTestRepository(at: repoURL, snapshotCount: 5, filesPerSnapshot: 10)
        
        measure {
            let expectation = XCTestExpectation(description: "Discovery completed")
            
            Task {
                do {
                    try await viewModel.startDiscovery(at: testDirectory)
                    while viewModel.scanningStatus != .completed(foundCount: 1) {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Discovery failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testDiscoveryPerformance_LargeRepository() throws {
        let repoURL = testDirectory.appending(path: "large_repo")
        try createTestRepository(at: repoURL, snapshotCount: 50, filesPerSnapshot: 100)
        
        measure {
            let expectation = XCTestExpectation(description: "Discovery completed")
            
            Task {
                do {
                    try await viewModel.startDiscovery(at: testDirectory)
                    while viewModel.scanningStatus != .completed(foundCount: 1) {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Discovery failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testIndexingPerformance_SmallRepository() throws {
        let repoURL = testDirectory.appending(path: "small_repo")
        try createTestRepository(at: repoURL, snapshotCount: 5, filesPerSnapshot: 10)
        
        measure {
            let expectation = XCTestExpectation(description: "Indexing completed")
            
            Task {
                do {
                    try await service.indexRepository(at: repoURL)
                    expectation.fulfill()
                } catch {
                    XCTFail("Indexing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testIndexingPerformance_LargeRepository() throws {
        let repoURL = testDirectory.appending(path: "large_repo")
        try createTestRepository(at: repoURL, snapshotCount: 50, filesPerSnapshot: 100)
        
        measure {
            let expectation = XCTestExpectation(description: "Indexing completed")
            
            Task {
                do {
                    try await service.indexRepository(at: repoURL)
                    expectation.fulfill()
                } catch {
                    XCTFail("Indexing failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testConcurrentDiscoveryPerformance() throws {
        // Create multiple test repositories
        for repoIndex in 0..<5 {
            let repoURL = testDirectory.appending(path: "repo_\(repoIndex)")
            try createTestRepository(at: repoURL, snapshotCount: 10, filesPerSnapshot: 20)
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Concurrent discovery completed")
            
            Task {
                do {
                    try await viewModel.startDiscovery(at: testDirectory)
                    while viewModel.scanningStatus != .completed(foundCount: 5) {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    expectation.fulfill()
                } catch {
                    XCTFail("Discovery failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
}
