import Testing
@testable import rBUM

/// Tests for BackupStatistics functionality
struct BackupStatisticsTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let resticService: MockResticService
        let notificationCenter: MockNotificationCenter
        let dateProvider: MockDateProvider
        let fileManager: MockFileManager
        
        init() {
            self.resticService = MockResticService()
            self.notificationCenter = MockNotificationCenter()
            self.dateProvider = MockDateProvider()
            self.fileManager = MockFileManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            resticService.reset()
            notificationCenter.reset()
            dateProvider.reset()
            fileManager.reset()
        }
        
        /// Create test statistics manager
        func createStatisticsManager() -> BackupStatisticsManager {
            BackupStatisticsManager(
                resticService: resticService,
                notificationCenter: notificationCenter,
                dateProvider: dateProvider,
                fileManager: fileManager
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initialize statistics manager", tags: ["init", "statistics"])
    func testInitialization() throws {
        // Given: Test context
        let context = TestContext()
        
        // When: Creating statistics manager
        let manager = context.createStatisticsManager()
        
        // Then: Manager is properly configured
        #expect(manager.isInitialized)
        #expect(manager.statisticsCount == 0)
    }
    
    // MARK: - Statistics Collection Tests
    
    @Test("Test statistics collection", tags: ["statistics", "collect"])
    func testStatisticsCollection() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        let repositories = MockData.Statistics.validRepositories
        
        // Test statistics collection
        for repository in repositories {
            // Collect statistics
            let stats = try manager.collectStatistics(repository)
            #expect(stats != nil)
            #expect(context.resticService.collectStatisticsCalled)
            #expect(context.notificationCenter.postNotificationCalled)
            
            // Verify statistics
            let verified = try manager.verifyStatistics(stats!)
            #expect(verified)
            
            context.reset()
        }
    }
    
    // MARK: - Statistics Analysis Tests
    
    @Test("Test statistics analysis", tags: ["statistics", "analyse"])
    func testStatisticsAnalysis() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        let testCases = MockData.Statistics.analysisData
        
        // Test statistics analysis
        for testCase in testCases {
            // Analyse statistics
            let analysis = try manager.analyseStatistics(testCase.stats)
            #expect(analysis.totalSize == testCase.expectedSize)
            #expect(analysis.fileCount == testCase.expectedFiles)
            #expect(analysis.deduplicationRatio == testCase.expectedRatio)
            
            // Verify trends
            let trends = try manager.calculateTrends(testCase.stats)
            #expect(trends.sizeGrowth == testCase.expectedGrowth)
            #expect(trends.efficiencyScore == testCase.expectedEfficiency)
            
            context.reset()
        }
    }
    
    // MARK: - Statistics Storage Tests
    
    @Test("Test statistics storage", tags: ["statistics", "storage"])
    func testStatisticsStorage() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        let testCases = MockData.Statistics.storageData
        
        // Test statistics storage
        for testCase in testCases {
            // Store statistics
            try manager.storeStatistics(testCase.stats)
            #expect(context.fileManager.writeDataCalled)
            
            // Retrieve statistics
            let retrieved = try manager.retrieveStatistics(testCase.id)
            #expect(retrieved == testCase.stats)
            #expect(context.fileManager.readDataCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Statistics Aggregation Tests
    
    @Test("Test statistics aggregation", tags: ["statistics", "aggregate"])
    func testStatisticsAggregation() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        let testCases = MockData.Statistics.aggregationData
        
        // Test statistics aggregation
        for testCase in testCases {
            // Aggregate statistics
            let aggregated = try manager.aggregateStatistics(testCase.stats)
            #expect(aggregated.totalSize == testCase.expectedTotalSize)
            #expect(aggregated.averageSize == testCase.expectedAverageSize)
            #expect(aggregated.maxSize == testCase.expectedMaxSize)
            #expect(aggregated.minSize == testCase.expectedMinSize)
            
            context.reset()
        }
    }
    
    // MARK: - Statistics Export Tests
    
    @Test("Test statistics export", tags: ["statistics", "export"])
    func testStatisticsExport() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        let testCases = MockData.Statistics.exportData
        
        // Test statistics export
        for testCase in testCases {
            // Export statistics
            let exported = try manager.exportStatistics(testCase.stats, format: testCase.format)
            #expect(!exported.isEmpty)
            #expect(context.fileManager.writeDataCalled)
            
            // Verify export
            let verified = try manager.verifyExport(exported, format: testCase.format)
            #expect(verified)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test statistics error handling", tags: ["statistics", "error"])
    func testErrorHandling() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        let errorCases = MockData.Statistics.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                try manager.handleStatisticsOperation(errorCase)
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Expected error
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .backupStatisticsError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle statistics edge cases", tags: ["statistics", "edge"])
    func testEdgeCases() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        // Test empty statistics
        do {
            let emptyStats = BackupStatistics()
            let analysis = try manager.analyseStatistics(emptyStats)
            #expect(analysis.totalSize == 0)
            #expect(analysis.fileCount == 0)
        } catch {
            throw TestFailure("Unexpected error for empty statistics")
        }
        
        // Test invalid repository
        do {
            try manager.collectStatistics(BackupRepository(id: "invalid"))
            throw TestFailure("Expected error for invalid repository")
        } catch {
            // Expected error
        }
        
        // Test corrupted storage
        do {
            try manager.retrieveStatistics("corrupted")
            throw TestFailure("Expected error for corrupted storage")
        } catch {
            // Expected error
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test statistics performance", tags: ["statistics", "performance"])
    func testPerformance() throws {
        // Given: Statistics manager
        let context = TestContext()
        let manager = context.createStatisticsManager()
        
        // Test analysis performance
        let startTime = context.dateProvider.now()
        let testStats = MockData.Statistics.analysisData[0].stats
        
        for _ in 0..<1000 {
            _ = try manager.analyseStatistics(testStats)
        }
        
        let endTime = context.dateProvider.now()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 1.0) // Should complete in under 1 second
        
        // Test aggregation performance
        let aggregationStartTime = context.dateProvider.now()
        let testAggregation = MockData.Statistics.aggregationData[0].stats
        
        for _ in 0..<100 {
            _ = try manager.aggregateStatistics(testAggregation)
        }
        
        let aggregationEndTime = context.dateProvider.now()
        
        let aggregationInterval = aggregationEndTime.timeIntervalSince(aggregationStartTime)
        #expect(aggregationInterval < 0.5) // Aggregation should be fast
    }
}
