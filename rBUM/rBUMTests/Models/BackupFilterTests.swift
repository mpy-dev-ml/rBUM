import Testing
@testable import rBUM

/// Tests for BackupFilter functionality
struct BackupFilterTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: MockUserDefaults
        let fileManager: MockFileManager
        
        init() {
            self.userDefaults = MockUserDefaults()
            self.fileManager = MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            fileManager.reset()
        }
        
        /// Create test filter
        func createFilter(
            includePatterns: [String] = ["*.txt", "*.doc"],
            excludePatterns: [String] = ["*.tmp", "*.log"],
            includeHidden: Bool = false,
            includeSystem: Bool = false,
            repository: Repository = MockData.Repository.validRepository
        ) -> BackupFilter {
            BackupFilter(
                includePatterns: includePatterns,
                excludePatterns: excludePatterns,
                includeHidden: includeHidden,
                includeSystem: includeSystem,
                repository: repository
            )
        }
        
        /// Create test file info
        func createFileInfo(
            path: String,
            isHidden: Bool = false,
            isSystem: Bool = false,
            modificationDate: Date = Date()
        ) -> FileInfo {
            FileInfo(
                path: path,
                isHidden: isHidden,
                isSystem: isSystem,
                modificationDate: modificationDate
            )
        }
    }
    
    // MARK: - Filter Creation Tests
    
    @Test("Create backup filters with different patterns", tags: ["filter", "init"])
    func testFilterCreation() throws {
        // Given: Different filter patterns
        let testCases: [(String, FilterType, Bool)] = [
            // Include patterns
            ("*.txt", .include, true),
            ("docs/*", .include, true),
            ("/absolute/path/*", .include, true),
            
            // Exclude patterns
            ("*.log", .exclude, true),
            ("temp/*", .exclude, true),
            ("/var/log/*", .exclude, true),
            
            // Invalid patterns
            ("", .include, false),
            ("   ", .exclude, false),
            ("*/invalid", .include, false)
        ]
        
        // When/Then: Test each filter pattern
        for (pattern, type, isValid) in testCases {
            let filter = BackupFilter(pattern: pattern, type: type)
            if isValid {
                #expect(filter.pattern == pattern)
                #expect(filter.type == type)
                #expect(filter.isValid)
            } else {
                #expect(!filter.isValid)
            }
        }
    }
    
    // MARK: - Pattern Matching Tests
    
    @Test("Test pattern matching", tags: ["filter", "matching"])
    func testPatternMatching() throws {
        // Given: Different paths and patterns
        let testCases: [(String, String, Bool)] = [
            // Exact matches
            ("test.txt", "*.txt", true),
            ("document.pdf", "*.pdf", true),
            ("image.jpg", "*.png", false),
            
            // Directory matches
            ("docs/file.txt", "docs/*", true),
            ("temp/cache.dat", "temp/*", true),
            ("other/file.txt", "docs/*", false),
            
            // Absolute path matches
            ("/usr/local/bin/app", "/usr/local/bin/*", true),
            ("/var/log/system.log", "/var/log/*.log", true),
            ("/home/user/file.txt", "/etc/*", false),
            
            // Complex patterns
            ("project/src/main.swift", "project/**/*.swift", true),
            ("build/temp/cache.dat", "**/temp/*.dat", true),
            ("test/fixtures/data.json", "test/**/data.json", true)
        ]
        
        // When/Then: Test pattern matching
        for (path, pattern, shouldMatch) in testCases {
            let filter = BackupFilter(pattern: pattern, type: .include)
            #expect(filter.matches(path: path) == shouldMatch)
        }
    }
    
    // MARK: - Filter List Tests
    
    @Test("Test filter list operations", tags: ["filter", "list"])
    func testFilterList() throws {
        // Given: List of filters
        var filterList = BackupFilterList()
        
        // Test adding filters
        let filters = [
            BackupFilter(pattern: "*.txt", type: .include),
            BackupFilter(pattern: "*.log", type: .exclude),
            BackupFilter(pattern: "temp/*", type: .exclude)
        ]
        
        for filter in filters {
            filterList.add(filter)
        }
        
        // Then: Filters are added correctly
        #expect(filterList.count == filters.count)
        #expect(filterList.includes.count == 1)
        #expect(filterList.excludes.count == 2)
        
        // Test removing filters
        filterList.remove(at: 0)
        #expect(filterList.count == filters.count - 1)
        #expect(filterList.includes.isEmpty)
        
        // Test clearing filters
        filterList.removeAll()
        #expect(filterList.isEmpty)
    }
    
    // MARK: - Path Filtering Tests
    
    @Test("Test path filtering", tags: ["filter", "path"])
    func testPathFiltering() throws {
        // Given: Filter list and test paths
        let context = TestContext()
        var filterList = BackupFilterList()
        
        // Add test filters
        filterList.add(BackupFilter(pattern: "*.txt", type: .include))
        filterList.add(BackupFilter(pattern: "*.log", type: .exclude))
        filterList.add(BackupFilter(pattern: "temp/*", type: .exclude))
        
        let testCases: [(String, Bool)] = [
            // Should include
            ("document.txt", true),
            ("data/file.txt", true),
            ("project/notes.txt", true),
            
            // Should exclude
            ("system.log", false),
            ("temp/cache.dat", false),
            ("logs/error.log", false),
            
            // No match (default exclude)
            ("image.jpg", false),
            ("script.sh", false)
        ]
        
        // When/Then: Test path filtering
        for (path, shouldInclude) in testCases {
            #expect(filterList.shouldInclude(path: path) == shouldInclude)
        }
    }
    
    // MARK: - Persistence Tests
    
    @Test("Test filter persistence", tags: ["filter", "persistence"])
    func testFilterPersistence() throws {
        // Given: Context and test filters
        let context = TestContext()
        let testFilters = [
            BackupFilter(pattern: "*.txt", type: .include),
            BackupFilter(pattern: "*.log", type: .exclude),
            BackupFilter(pattern: "temp/*", type: .exclude)
        ]
        
        // When: Storing filters
        let filterList = BackupFilterList(filters: testFilters)
        context.userDefaults.set(filterList.persistenceData, forKey: "BackupFilters")
        
        // Then: Filters can be retrieved
        if let data = context.userDefaults.object(forKey: "BackupFilters") as? Data,
           let retrievedList = try? BackupFilterList.fromPersistenceData(data) {
            #expect(retrievedList.count == filterList.count)
            for (original, retrieved) in zip(filterList.filters, retrievedList.filters) {
                #expect(original.pattern == retrieved.pattern)
                #expect(original.type == retrieved.type)
            }
        } else {
            throw TestFailure("Failed to persist and retrieve filters")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle filter edge cases", tags: ["filter", "edge"])
    func testEdgeCases() throws {
        // Test empty pattern
        let emptyFilter = BackupFilter(pattern: "", type: .include)
        #expect(!emptyFilter.isValid)
        
        // Test whitespace pattern
        let whitespaceFilter = BackupFilter(pattern: "   ", type: .include)
        #expect(!whitespaceFilter.isValid)
        
        // Test very long pattern
        let longPattern = String(repeating: "a", count: 1000)
        let longFilter = BackupFilter(pattern: longPattern, type: .include)
        #expect(!longFilter.isValid)
        
        // Test invalid characters
        let invalidFilter = BackupFilter(pattern: "test\0file", type: .include)
        #expect(!invalidFilter.isValid)
        
        // Test duplicate filters
        var filterList = BackupFilterList()
        let duplicateFilter = BackupFilter(pattern: "*.txt", type: .include)
        filterList.add(duplicateFilter)
        filterList.add(duplicateFilter)
        #expect(filterList.count == 1)
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize with default values", tags: ["init", "filter"])
    func testDefaultInitialization() throws {
        // Given: Default filter parameters
        let context = TestContext()
        
        // When: Creating filter
        let filter = context.createFilter()
        
        // Then: Filter is configured correctly
        #expect(filter.includePatterns == ["*.txt", "*.doc"])
        #expect(filter.excludePatterns == ["*.tmp", "*.log"])
        #expect(!filter.includeHidden)
        #expect(!filter.includeSystem)
    }
    
    @Test("Initialize with custom values", tags: ["init", "filter"])
    func testCustomInitialization() throws {
        // Given: Custom filter parameters
        let context = TestContext()
        let includePatterns = ["*.swift", "*.md"]
        let excludePatterns = ["*.swiftdeps", "*.build"]
        
        // When: Creating filter
        let filter = context.createFilter(
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            includeHidden: true,
            includeSystem: true
        )
        
        // Then: Filter is configured correctly
        #expect(filter.includePatterns == includePatterns)
        #expect(filter.excludePatterns == excludePatterns)
        #expect(filter.includeHidden)
        #expect(filter.includeSystem)
    }
    
    // MARK: - Pattern Tests
    
    @Test("Match file patterns", tags: ["pattern", "filter"])
    func testPatternMatching() throws {
        // Given: Filter with patterns
        let context = TestContext()
        let filter = context.createFilter(
            includePatterns: ["*.txt", "*.doc"],
            excludePatterns: ["temp.*", "*.tmp"]
        )
        
        // When/Then: Test pattern matching
        let testCases: [(String, Bool)] = [
            ("document.txt", true),
            ("report.doc", true),
            ("script.sh", false),
            ("temp.txt", false),
            ("data.tmp", false)
        ]
        
        for (path, shouldMatch) in testCases {
            let fileInfo = context.createFileInfo(path: path)
            #expect(filter.shouldInclude(fileInfo) == shouldMatch)
        }
    }
    
    // MARK: - Hidden File Tests
    
    @Test("Handle hidden files", tags: ["hidden", "filter"])
    func testHiddenFiles() throws {
        // Given: Filters with different hidden file settings
        let context = TestContext()
        let includeHiddenFilter = context.createFilter(includeHidden: true)
        let excludeHiddenFilter = context.createFilter(includeHidden: false)
        
        // When/Then: Test hidden file handling
        let testCases: [(String, Bool, Bool)] = [
            ("normal.txt", false, true),      // Normal file
            (".hidden.txt", true, false),     // Hidden file
            (".git/config", true, false),     // Hidden directory file
            ("folder/.hidden", true, false)   // Hidden file in folder
        ]
        
        for (path, isHidden, shouldIncludeWhenHidden) in testCases {
            let fileInfo = context.createFileInfo(
                path: path,
                isHidden: isHidden
            )
            
            #expect(includeHiddenFilter.shouldInclude(fileInfo))
            #expect(excludeHiddenFilter.shouldInclude(fileInfo) == shouldIncludeWhenHidden)
        }
    }
    
    // MARK: - System File Tests
    
    @Test("Handle system files", tags: ["system", "filter"])
    func testSystemFiles() throws {
        // Given: Filters with different system file settings
        let context = TestContext()
        let includeSystemFilter = context.createFilter(includeSystem: true)
        let excludeSystemFilter = context.createFilter(includeSystem: false)
        
        // When/Then: Test system file handling
        let testCases: [(String, Bool, Bool)] = [
            ("user.txt", false, true),           // User file
            ("system.dat", true, false),         // System file
            ("/var/log/system.log", true, false) // System log
        ]
        
        for (path, isSystem, shouldIncludeWhenSystem) in testCases {
            let fileInfo = context.createFileInfo(
                path: path,
                isSystem: isSystem
            )
            
            #expect(includeSystemFilter.shouldInclude(fileInfo))
            #expect(excludeSystemFilter.shouldInclude(fileInfo) == shouldIncludeWhenSystem)
        }
    }
    
    // MARK: - Combined Filter Tests
    
    @Test("Apply combined filters", tags: ["combined", "filter"])
    func testCombinedFilters() throws {
        // Given: Filter with multiple conditions
        let context = TestContext()
        let filter = context.createFilter(
            includePatterns: ["*.txt", "*.doc"],
            excludePatterns: ["temp.*", "*.tmp"],
            includeHidden: false,
            includeSystem: false
        )
        
        // When/Then: Test combined filtering
        let testCases: [(String, Bool, Bool, Bool)] = [
            ("document.txt", false, false, true),   // Normal document
            (".hidden.txt", true, false, false),    // Hidden document
            ("system.txt", false, true, false),     // System document
            ("temp.txt", false, false, false),      // Excluded pattern
            ("script.sh", false, false, false)      // Non-matching pattern
        ]
        
        for (path, isHidden, isSystem, shouldInclude) in testCases {
            let fileInfo = context.createFileInfo(
                path: path,
                isHidden: isHidden,
                isSystem: isSystem
            )
            #expect(filter.shouldInclude(fileInfo) == shouldInclude)
        }
    }
    
    // MARK: - Pattern Validation Tests
    
    @Test("Validate patterns", tags: ["validation", "filter"])
    func testPatternValidation() throws {
        // Given: Various pattern combinations
        let context = TestContext()
        let testCases: [([String], [String], Bool)] = [
            (["*.txt"], ["*.tmp"], true),              // Valid patterns
            ([], [], true),                            // Empty patterns
            ([""], [""], false),                       // Empty string patterns
            (["*"], ["*"], true),                      // Wildcard patterns
            (["*."], ["."], false),                    // Invalid patterns
            (["**"], ["**"], true),                    // Double wildcards
            (["*.{txt,doc}"], ["*.{tmp,log}"], true)  // Extension groups
        ]
        
        // When/Then: Test pattern validation
        for (include, exclude, isValid) in testCases {
            let filter = context.createFilter(
                includePatterns: include,
                excludePatterns: exclude
            )
            #expect(filter.hasValidPatterns() == isValid)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle edge cases", tags: ["edge", "filter"])
    func testEdgeCases() throws {
        // Given: Edge case scenarios
        let context = TestContext()
        
        // Test empty patterns
        let emptyFilter = context.createFilter(
            includePatterns: [],
            excludePatterns: []
        )
        let normalFile = context.createFileInfo(path: "test.txt")
        #expect(emptyFilter.shouldInclude(normalFile))
        
        // Test conflicting patterns
        let conflictingFilter = context.createFilter(
            includePatterns: ["*.txt"],
            excludePatterns: ["*.txt"]
        )
        let textFile = context.createFileInfo(path: "test.txt")
        #expect(!conflictingFilter.shouldInclude(textFile))
        
        // Test case sensitivity
        let caseFilter = context.createFilter(
            includePatterns: ["*.TXT"],
            excludePatterns: ["*.tmp"]
        )
        let lowerFile = context.createFileInfo(path: "test.txt")
        let upperFile = context.createFileInfo(path: "test.TXT")
        #expect(caseFilter.shouldInclude(lowerFile))
        #expect(caseFilter.shouldInclude(upperFile))
        
        // Test very long paths
        let longPath = String(repeating: "a", count: 1000) + ".txt"
        let longPathFile = context.createFileInfo(path: longPath)
        let normalFilter = context.createFilter()
        #expect(normalFilter.shouldInclude(longPathFile))
    }
}

// MARK: - Mock Implementations

/// Mock implementation of UserDefaults for testing
final class MockUserDefaults: UserDefaults {
    var storage: [String: Any] = [:]
    
    override func set(_ value: Any?, forKey defaultName: String) {
        if let value = value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }
    
    override func object(forKey defaultName: String) -> Any? {
        storage[defaultName]
    }
    
    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func reset() {
        storage.removeAll()
    }
}

/// Mock implementation of FileManager for testing
final class MockFileManager: FileManager {
    var files: Set<String> = []
    var directories: Set<String> = []
    
    override func fileExists(atPath path: String) -> Bool {
        files.contains(path)
    }
    
    override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        if let isDirectory = isDirectory {
            isDirectory.pointee = ObjCBool(directories.contains(path))
        }
        return files.contains(path) || directories.contains(path)
    }
    
    func addFile(_ path: String) {
        files.insert(path)
    }
    
    func addDirectory(_ path: String) {
        directories.insert(path)
    }
    
    func reset() {
        files.removeAll()
        directories.removeAll()
    }
}
