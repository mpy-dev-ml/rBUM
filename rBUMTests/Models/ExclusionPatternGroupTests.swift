@testable import rBUM
import XCTest

final class ExclusionPatternGroupTests: XCTestCase {
    func testPatternGroups() throws {
        // Given a pattern group
        let groupId = UUID()
        let group = try ExclusionPatternGroup(
            id: groupId,
            name: "Development Files",
            description: "Common development files to exclude",
            patterns: [
                ExclusionPattern(pattern: "node_modules", isDirectory: true, groupId: groupId),
                ExclusionPattern(pattern: "*.pyc", groupId: groupId),
                ExclusionPattern(pattern: ".git", isDirectory: true, groupId: groupId)
            ]
        )
        
        // When creating a configuration with the group
        let config = try BackupConfiguration(
            name: "Test Backup",
            sources: [URL(fileURLWithPath: "/tmp")],
            exclusionPatternGroups: [group]
        )
        
        // Then the group should be accessible
        XCTAssertEqual(config.exclusionPatternGroups.count, 1)
        XCTAssertEqual(config.exclusionPatternGroups.first?.name, "Development Files")
    }
    
    func testPatternGroupValidation() throws {
        // When creating a group with no patterns
        XCTAssertThrowsError(
            try ExclusionPatternGroup(
                name: "Empty Group",
                patterns: []
            )
        ) { error in
            XCTAssertTrue(error is ConfigurationError)
            XCTAssertTrue(error.localizedDescription.contains("must contain at least one pattern"))
        }
        
        // When creating a group with an empty name
        XCTAssertThrowsError(
            try ExclusionPatternGroup(
                name: "",
                patterns: [ExclusionPattern(pattern: "test")]
            )
        ) { error in
            XCTAssertTrue(error is ConfigurationError)
            XCTAssertTrue(error.localizedDescription.contains("name cannot be empty"))
        }
    }
}
