//
//  BackupStatisticsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupStatisticsTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup statistics with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let filesChanged = 10
        let filesNew = 5
        let filesUnmodified = 100
        let dataAdded: UInt64 = 1024 * 1024 // 1 MB
        let totalDuration: TimeInterval = 60 // 1 minute
        
        // When
        let stats = BackupStatistics(
            filesChanged: filesChanged,
            filesNew: filesNew,
            filesUnmodified: filesUnmodified,
            dataAdded: dataAdded,
            totalDuration: totalDuration
        )
        
        // Then
        #expect(stats.filesChanged == filesChanged)
        #expect(stats.filesNew == filesNew)
        #expect(stats.filesUnmodified == filesUnmodified)
        #expect(stats.dataAdded == dataAdded)
        #expect(stats.totalDuration == totalDuration)
    }
    
    // MARK: - Calculated Properties Tests
    
    @Test("Calculate total files", tags: ["model", "calculation"])
    func testTotalFiles() throws {
        let testCases = [
            // No files
            (0, 0, 0, 0),
            // Only changed files
            (10, 0, 0, 10),
            // Only new files
            (0, 10, 0, 10),
            // Only unmodified files
            (0, 0, 10, 10),
            // Mixed files
            (5, 10, 15, 30),
            // Large numbers
            (1000, 2000, 3000, 6000)
        ]
        
        for (changed, new, unmodified, expected) in testCases {
            let stats = BackupStatistics(
                filesChanged: changed,
                filesNew: new,
                filesUnmodified: unmodified,
                dataAdded: 0,
                totalDuration: 1
            )
            
            #expect(stats.totalFiles == expected)
        }
    }
    
    @Test("Calculate average speed", tags: ["model", "calculation"])
    func testAverageSpeed() throws {
        let testCases = [
            // No data
            (UInt64(0), TimeInterval(1), 0.0),
            // 1 MB in 1 second
            (UInt64(1024 * 1024), TimeInterval(1), 1024 * 1024),
            // 1 GB in 1 minute
            (UInt64(1024 * 1024 * 1024), TimeInterval(60), Double(1024 * 1024 * 1024) / 60),
            // Zero duration (should handle division by zero)
            (UInt64(1024), TimeInterval(0), 0.0)
        ]
        
        for (dataAdded, duration, expected) in testCases {
            let stats = BackupStatistics(
                filesChanged: 0,
                filesNew: 0,
                filesUnmodified: 0,
                dataAdded: dataAdded,
                totalDuration: duration
            )
            
            if duration == 0 {
                #expect(stats.averageSpeed.isZero)
            } else {
                #expect(abs(stats.averageSpeed - expected) < 0.001)
            }
        }
    }
    
    // MARK: - Formatting Tests
    
    @Test("Format data size", tags: ["model", "formatting"])
    func testDataSizeFormatting() throws {
        let testCases = [
            // Bytes
            (UInt64(500), "500 B"),
            // Kilobytes
            (UInt64(1024), "1.0 KB"),
            (UInt64(1536), "1.5 KB"),
            // Megabytes
            (UInt64(1024 * 1024), "1.0 MB"),
            (UInt64(1024 * 1024 * 1.5), "1.5 MB"),
            // Gigabytes
            (UInt64(1024 * 1024 * 1024), "1.0 GB"),
            (UInt64(1024 * 1024 * 1024 * 2.5), "2.5 GB"),
            // Terabytes
            (UInt64(1024 * 1024 * 1024 * 1024), "1.0 TB")
        ]
        
        for (bytes, expected) in testCases {
            let stats = BackupStatistics(
                filesChanged: 0,
                filesNew: 0,
                filesUnmodified: 0,
                dataAdded: bytes,
                totalDuration: 1
            )
            
            #expect(stats.formattedDataAdded == expected)
        }
    }
    
    @Test("Format duration", tags: ["model", "formatting"])
    func testDurationFormatting() throws {
        let testCases = [
            // Seconds
            (TimeInterval(30), "30 seconds"),
            // Minutes
            (TimeInterval(60), "1 minute"),
            (TimeInterval(90), "1 minute 30 seconds"),
            // Hours
            (TimeInterval(3600), "1 hour"),
            (TimeInterval(3660), "1 hour 1 minute"),
            (TimeInterval(3690), "1 hour 1 minute 30 seconds"),
            // Days
            (TimeInterval(86400), "1 day"),
            (TimeInterval(90000), "1 day 1 hour"),
            // Multiple units
            (TimeInterval(93690), "1 day 2 hours 1 minute 30 seconds")
        ]
        
        for (duration, expected) in testCases {
            let stats = BackupStatistics(
                filesChanged: 0,
                filesNew: 0,
                filesUnmodified: 0,
                dataAdded: 0,
                totalDuration: duration
            )
            
            #expect(stats.formattedDuration == expected)
        }
    }
    
    @Test("Format speed", tags: ["model", "formatting"])
    func testSpeedFormatting() throws {
        let testCases = [
            // Bytes per second
            (UInt64(500), TimeInterval(1), "500 B/s"),
            // Kilobytes per second
            (UInt64(1024), TimeInterval(1), "1.0 KB/s"),
            // Megabytes per second
            (UInt64(1024 * 1024), TimeInterval(1), "1.0 MB/s"),
            // Gigabytes per second
            (UInt64(1024 * 1024 * 1024), TimeInterval(1), "1.0 GB/s"),
            // Variable speeds
            (UInt64(1024 * 1024), TimeInterval(2), "512.0 KB/s"),
            (UInt64(1024 * 1024 * 10), TimeInterval(5), "2.0 MB/s")
        ]
        
        for (dataAdded, duration, expected) in testCases {
            let stats = BackupStatistics(
                filesChanged: 0,
                filesNew: 0,
                filesUnmodified: 0,
                dataAdded: dataAdded,
                totalDuration: duration
            )
            
            #expect(stats.formattedSpeed == expected)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup statistics for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let stats1 = BackupStatistics(
            filesChanged: 10,
            filesNew: 5,
            filesUnmodified: 100,
            dataAdded: 1024,
            totalDuration: 60
        )
        
        let stats2 = BackupStatistics(
            filesChanged: 10,
            filesNew: 5,
            filesUnmodified: 100,
            dataAdded: 1024,
            totalDuration: 60
        )
        
        let stats3 = BackupStatistics(
            filesChanged: 20,
            filesNew: 5,
            filesUnmodified: 100,
            dataAdded: 1024,
            totalDuration: 60
        )
        
        #expect(stats1 == stats2)
        #expect(stats1 != stats3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup statistics", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Empty statistics
            BackupStatistics(
                filesChanged: 0,
                filesNew: 0,
                filesUnmodified: 0,
                dataAdded: 0,
                totalDuration: 0
            ),
            // Typical statistics
            BackupStatistics(
                filesChanged: 10,
                filesNew: 5,
                filesUnmodified: 100,
                dataAdded: 1024 * 1024,
                totalDuration: 60
            ),
            // Large numbers
            BackupStatistics(
                filesChanged: 1000,
                filesNew: 2000,
                filesUnmodified: 3000,
                dataAdded: 1024 * 1024 * 1024,
                totalDuration: 3600
            )
        ]
        
        for stats in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(stats)
            let decoded = try decoder.decode(BackupStatistics.self, from: data)
            
            // Then
            #expect(decoded == stats)
            #expect(decoded.totalFiles == stats.totalFiles)
            #expect(decoded.averageSpeed == stats.averageSpeed)
            #expect(decoded.formattedDataAdded == stats.formattedDataAdded)
            #expect(decoded.formattedDuration == stats.formattedDuration)
            #expect(decoded.formattedSpeed == stats.formattedSpeed)
        }
    }
}
