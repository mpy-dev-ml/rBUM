@testable import rBUM
import XCTest

final class ExclusionPatternTests: XCTestCase {
    func testPatternTypeMatching() throws {
        // Given patterns of different types
        let exactPattern = ExclusionPattern(pattern: "test.txt", patternType: .exact)
        let globPattern = ExclusionPattern(pattern: "*.txt", patternType: .glob)
        let regexPattern = ExclusionPattern(pattern: "test[0-9]+\\.txt", patternType: .regex)
        
        // Test exact matching
        XCTAssertTrue(exactPattern.matches(path: "test.txt"))
        XCTAssertFalse(exactPattern.matches(path: "test2.txt"))
        
        // Test glob matching
        XCTAssertTrue(globPattern.matches(path: "test.txt"))
        XCTAssertTrue(globPattern.matches(path: "other.txt"))
        XCTAssertFalse(globPattern.matches(path: "test.doc"))
        
        // Test regex matching
        XCTAssertTrue(regexPattern.matches(path: "test1.txt"))
        XCTAssertTrue(regexPattern.matches(path: "test42.txt"))
        XCTAssertFalse(regexPattern.matches(path: "test.txt"))
    }
    
    func testInvalidRegexPattern() throws {
        // Given an invalid regex pattern
        XCTAssertThrowsError(
            try ExclusionPattern(
                pattern: "[invalid",
                patternType: .regex
            ).validate()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid regular expression"))
        }
    }
    
    func testCategoryValidationRules() throws {
        // Test system category validation
        XCTAssertThrowsError(
            try ExclusionPattern(
                pattern: "test",
                patternType: .regex,
                category: .system
            ).validate()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("Pattern type 'regex' is not allowed"))
        }
        
        // Test security category validation
        XCTAssertThrowsError(
            try ExclusionPattern(
                pattern: "*secret*",
                patternType: .glob,
                category: .security
            ).validate()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("Pattern type 'glob' is not allowed"))
        }
        
        // Test performance category validation
        XCTAssertThrowsError(
            try ExclusionPattern(
                pattern: "cache",
                patternType: .glob,
                isDirectory: false,
                category: .performance
            ).validate()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("must be directory patterns"))
        }
        
        // Test pattern length validation
        XCTAssertThrowsError(
            try ExclusionPattern(
                pattern: String(repeating: "a", count: 300),
                category: .system
            ).validate()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("exceeds maximum length"))
        }
        
        // Test disallowed patterns
        XCTAssertThrowsError(
            try ExclusionPattern(
                pattern: "/*",
                category: .system
            ).validate()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("not allowed in category"))
        }
    }
}
