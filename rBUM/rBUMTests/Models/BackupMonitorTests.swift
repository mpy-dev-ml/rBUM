//
//  BackupMonitorTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupMonitorTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup monitor with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        
        // When
        let monitor = BackupMonitor(
            id: id,
            repositoryId: repositoryId
        )
        
        // Then
        #expect(monitor.id == id)
        #expect(monitor.repositoryId == repositoryId)
        #expect(monitor.isActive == false)
        #expect(monitor.lastCheckTime == nil)
        #expect(monitor.checkInterval == 300) // Default 5 minutes
    }
    
    @Test("Initialize backup monitor with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositoryId = UUID()
        let isActive = true
        let lastCheckTime = Date()
        let checkInterval: TimeInterval = 600 // 10 minutes
        let filters = [BackupFilter(pattern: "*.tmp", type: .exclude)]
        
        // When
        let monitor = BackupMonitor(
            id: id,
            repositoryId: repositoryId,
            isActive: isActive,
            lastCheckTime: lastCheckTime,
            checkInterval: checkInterval,
            filters: filters
        )
        
        // Then
        #expect(monitor.id == id)
        #expect(monitor.repositoryId == repositoryId)
        #expect(monitor.isActive == isActive)
        #expect(monitor.lastCheckTime == lastCheckTime)
        #expect(monitor.checkInterval == checkInterval)
        #expect(monitor.filters == filters)
    }
    
    // MARK: - Activity Tests
    
    @Test("Handle monitor activity state", tags: ["model", "activity"])
    func testActivityState() throws {
        // Given
        var monitor = BackupMonitor(
            id: UUID(),
            repositoryId: UUID()
        )
        
        // Test activation
        monitor.activate()
        #expect(monitor.isActive)
        #expect(monitor.lastCheckTime != nil)
        
        // Test deactivation
        monitor.deactivate()
        #expect(!monitor.isActive)
    }
    
    // MARK: - Check Interval Tests
    
    @Test("Handle check interval updates", tags: ["model", "interval"])
    func testCheckInterval() throws {
        let testCases: [(TimeInterval, Bool)] = [
            (60, true),      // 1 minute
            (300, true),     // 5 minutes
            (3600, true),    // 1 hour
            (86400, true),   // 1 day
            (0, false),      // Invalid: 0 seconds
            (-1, false),     // Invalid: negative
            (30, false)      // Invalid: too short
        ]
        
        for (interval, isValid) in testCases {
            var monitor = BackupMonitor(
                id: UUID(),
                repositoryId: UUID()
            )
            
            if isValid {
                monitor.checkInterval = interval
                #expect(monitor.checkInterval == interval)
            } else {
                let originalInterval = monitor.checkInterval
                monitor.checkInterval = interval
                #expect(monitor.checkInterval == originalInterval)
            }
        }
    }
    
    // MARK: - Filter Tests
    
    @Test("Handle backup filters", tags: ["model", "filters"])
    func testFilters() throws {
        // Given
        var monitor = BackupMonitor(
            id: UUID(),
            repositoryId: UUID()
        )
        
        let filters = [
            BackupFilter(pattern: "*.tmp", type: .exclude),
            BackupFilter(pattern: "*.log", type: .exclude),
            BackupFilter(pattern: "*.dat", type: .include)
        ]
        
        // Test adding filters
        for filter in filters {
            monitor.addFilter(filter)
        }
        #expect(monitor.filters.count == filters.count)
        
        // Test removing filters
        monitor.removeFilter(filters[0])
        #expect(monitor.filters.count == filters.count - 1)
        #expect(!monitor.filters.contains(filters[0]))
        
        // Test clearing filters
        monitor.clearFilters()
        #expect(monitor.filters.isEmpty)
    }
    
    // MARK: - Check Tests
    
    @Test("Handle backup checks", tags: ["model", "check"])
    func testBackupChecks() throws {
        // Given
        var monitor = BackupMonitor(
            id: UUID(),
            repositoryId: UUID(),
            isActive: true,
            checkInterval: 60
        )
        
        // Test initial check
        let initialCheck = monitor.shouldCheck()
        #expect(initialCheck)
        
        // Test after recent check
        monitor.lastCheckTime = Date()
        let immediateCheck = monitor.shouldCheck()
        #expect(!immediateCheck)
        
        // Test after interval
        monitor.lastCheckTime = Date(timeIntervalSinceNow: -120)
        let intervalCheck = monitor.shouldCheck()
        #expect(intervalCheck)
    }
    
    // MARK: - Event Tests
    
    @Test("Handle monitor events", tags: ["model", "events"])
    func testEvents() throws {
        // Given
        var monitor = BackupMonitor(
            id: UUID(),
            repositoryId: UUID(),
            isActive: true
        )
        
        // Test file change event
        let fileEvent = BackupMonitorEvent(
            type: .fileChanged,
            path: "/test/file.txt",
            timestamp: Date()
        )
        monitor.handleEvent(fileEvent)
        #expect(monitor.lastEventTime == fileEvent.timestamp)
        
        // Test directory change event
        let dirEvent = BackupMonitorEvent(
            type: .directoryChanged,
            path: "/test/dir",
            timestamp: Date()
        )
        monitor.handleEvent(dirEvent)
        #expect(monitor.lastEventTime == dirEvent.timestamp)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Track monitoring statistics", tags: ["model", "statistics"])
    func testStatistics() throws {
        // Given
        var monitor = BackupMonitor(
            id: UUID(),
            repositoryId: UUID(),
            isActive: true
        )
        
        // Test event counting
        for _ in 0..<5 {
            monitor.handleEvent(BackupMonitorEvent(
                type: .fileChanged,
                path: "/test/file.txt",
                timestamp: Date()
            ))
        }
        
        #expect(monitor.statistics.totalEvents == 5)
        #expect(monitor.statistics.lastEventTime != nil)
        #expect(monitor.statistics.averageEventsPerHour > 0)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare monitors for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let monitor1 = BackupMonitor(
            id: UUID(),
            repositoryId: UUID(),
            isActive: true,
            checkInterval: 300
        )
        
        let monitor2 = BackupMonitor(
            id: monitor1.id,
            repositoryId: monitor1.repositoryId,
            isActive: true,
            checkInterval: 300
        )
        
        let monitor3 = BackupMonitor(
            id: UUID(),
            repositoryId: monitor1.repositoryId,
            isActive: true,
            checkInterval: 300
        )
        
        #expect(monitor1 == monitor2)
        #expect(monitor1 != monitor3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup monitor", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Basic monitor
            BackupMonitor(
                id: UUID(),
                repositoryId: UUID()
            ),
            // Active monitor with filters
            BackupMonitor(
                id: UUID(),
                repositoryId: UUID(),
                isActive: true,
                lastCheckTime: Date(),
                checkInterval: 300,
                filters: [
                    BackupFilter(pattern: "*.tmp", type: .exclude)
                ]
            )
        ]
        
        for monitor in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(monitor)
            let decoded = try decoder.decode(BackupMonitor.self, from: data)
            
            // Then
            #expect(decoded.id == monitor.id)
            #expect(decoded.repositoryId == monitor.repositoryId)
            #expect(decoded.isActive == monitor.isActive)
            #expect(decoded.lastCheckTime == monitor.lastCheckTime)
            #expect(decoded.checkInterval == monitor.checkInterval)
            #expect(decoded.filters == monitor.filters)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup monitor properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid monitor
            (UUID(), UUID(), 300, true),
            // Invalid check interval
            (UUID(), UUID(), 0, false),
            // Invalid check interval
            (UUID(), UUID(), -1, false),
            // Invalid check interval (too short)
            (UUID(), UUID(), 30, false)
        ]
        
        for (id, repoId, interval, isValid) in testCases {
            let monitor = BackupMonitor(
                id: id,
                repositoryId: repoId,
                checkInterval: interval
            )
            
            if isValid {
                #expect(monitor.isValid)
            } else {
                #expect(!monitor.isValid)
            }
        }
    }
}
