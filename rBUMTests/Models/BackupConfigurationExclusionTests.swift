@testable import rBUM
import XCTest

final class BackupConfigurationExclusionTests: XCTestCase {
    let testSourceURL1 = URL(fileURLWithPath: "/tmp/test1")
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: testSourceURL1, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testSourceURL1)
        super.tearDown()
    }
    
    func testExclusionPatterns() throws {
        // Given a configuration with exclusion patterns
        let config = try BackupConfiguration(
            name: "Test",
            sources: [testSourceURL1],
            exclusionPatterns: [
                ExclusionPattern(pattern: "*.tmp"),
                ExclusionPattern(pattern: "cache", isDirectory: true)
            ]
        )
        
        // Then
        XCTAssertEqual(config.exclusionPatterns.count, 2)
        
        // Test pattern matching
        let (tmpExcluded, _) = config.shouldExclude(path: "test.tmp")
        let (cacheExcluded, _) = config.shouldExclude(path: "cache")
        let (otherExcluded, _) = config.shouldExclude(path: "test.txt")
        
        XCTAssertTrue(tmpExcluded)
        XCTAssertTrue(cacheExcluded)
        XCTAssertFalse(otherExcluded)
    }
    
    func testPatternInheritance() throws {
        // Given a configuration with directory patterns
        let config = try BackupConfiguration(
            name: "Test",
            sources: [testSourceURL1],
            exclusionPatterns: [
                ExclusionPattern(
                    pattern: "cache",
                    isDirectory: true,
                    inheritsToSubdirectories: false
                )
            ]
        )
        
        // Test pattern inheritance
        let (cacheExcluded, _) = config.shouldExclude(path: "cache")
        let (subCacheExcluded, _) = config.shouldExclude(path: "cache/subdir")
        
        XCTAssertTrue(cacheExcluded)
        XCTAssertFalse(subCacheExcluded)
    }
}
