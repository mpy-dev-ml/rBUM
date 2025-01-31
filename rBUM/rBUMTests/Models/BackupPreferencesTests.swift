//
//  BackupPreferencesTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupPreferencesTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup preferences with default values", tags: ["basic", "model"])
    func testDefaultInitialization() throws {
        // When
        let preferences = BackupPreferences()
        
        // Then
        #expect(preferences.compressionLevel == .default)
        #expect(preferences.parallelOperations == 1)
        #expect(preferences.bandwidthLimit == nil)
        #expect(preferences.notificationsEnabled)
        #expect(preferences.autoBackupEnabled == false)
        #expect(preferences.retentionPolicy == .default)
        #expect(preferences.excludeSystemFiles)
        #expect(preferences.excludeHiddenFiles)
    }
    
    @Test("Initialize backup preferences with custom values", tags: ["basic", "model"])
    func testCustomInitialization() throws {
        // Given
        let compressionLevel = CompressionLevel.maximum
        let parallelOperations = 4
        let bandwidthLimit: UInt64 = 1024 * 1024 // 1 MB/s
        let notificationsEnabled = false
        let autoBackupEnabled = true
        let retentionPolicy = RetentionPolicy.custom(days: 30)
        let excludeSystemFiles = false
        let excludeHiddenFiles = false
        
        // When
        let preferences = BackupPreferences(
            compressionLevel: compressionLevel,
            parallelOperations: parallelOperations,
            bandwidthLimit: bandwidthLimit,
            notificationsEnabled: notificationsEnabled,
            autoBackupEnabled: autoBackupEnabled,
            retentionPolicy: retentionPolicy,
            excludeSystemFiles: excludeSystemFiles,
            excludeHiddenFiles: excludeHiddenFiles
        )
        
        // Then
        #expect(preferences.compressionLevel == compressionLevel)
        #expect(preferences.parallelOperations == parallelOperations)
        #expect(preferences.bandwidthLimit == bandwidthLimit)
        #expect(preferences.notificationsEnabled == notificationsEnabled)
        #expect(preferences.autoBackupEnabled == autoBackupEnabled)
        #expect(preferences.retentionPolicy == retentionPolicy)
        #expect(preferences.excludeSystemFiles == excludeSystemFiles)
        #expect(preferences.excludeHiddenFiles == excludeHiddenFiles)
    }
    
    // MARK: - Compression Level Tests
    
    @Test("Handle compression levels", tags: ["model", "compression"])
    func testCompressionLevels() throws {
        let testCases: [(CompressionLevel, String, Int)] = [
            (.none, "No Compression", 0),
            (.minimum, "Minimum Compression", 1),
            (.default, "Default Compression", 6),
            (.maximum, "Maximum Compression", 9)
        ]
        
        for (level, description, value) in testCases {
            var preferences = BackupPreferences()
            preferences.compressionLevel = level
            
            #expect(preferences.compressionLevel == level)
            #expect(preferences.compressionLevel.description == description)
            #expect(preferences.compressionLevel.value == value)
        }
    }
    
    // MARK: - Parallel Operations Tests
    
    @Test("Handle parallel operations limits", tags: ["model", "parallel"])
    func testParallelOperations() throws {
        let testCases = [
            // Valid values
            1, 2, 4, 8, 16,
            // Invalid values (should be clamped)
            0, -1, 33, 100
        ]
        
        for operations in testCases {
            var preferences = BackupPreferences()
            preferences.parallelOperations = operations
            
            let expectedValue = max(1, min(operations, 32))
            #expect(preferences.parallelOperations == expectedValue)
        }
    }
    
    // MARK: - Bandwidth Tests
    
    @Test("Handle bandwidth limits", tags: ["model", "bandwidth"])
    func testBandwidthLimits() throws {
        let testCases: [(UInt64?, String)] = [
            // No limit
            (nil, "Unlimited"),
            // Bytes per second
            (500, "500 B/s"),
            // Kilobytes per second
            (1024, "1.0 KB/s"),
            // Megabytes per second
            (1024 * 1024, "1.0 MB/s"),
            // Gigabytes per second
            (1024 * 1024 * 1024, "1.0 GB/s")
        ]
        
        for (limit, formattedLimit) in testCases {
            var preferences = BackupPreferences()
            preferences.bandwidthLimit = limit
            
            #expect(preferences.bandwidthLimit == limit)
            #expect(preferences.formattedBandwidthLimit == formattedLimit)
        }
    }
    
    // MARK: - Retention Policy Tests
    
    @Test("Handle retention policies", tags: ["model", "retention"])
    func testRetentionPolicies() throws {
        let testCases: [(RetentionPolicy, String)] = [
            (.default, "Default Retention (7 days)"),
            (.none, "No Retention"),
            (.custom(days: 30), "30 Days Retention"),
            (.custom(days: 90), "90 Days Retention"),
            (.custom(days: 365), "365 Days Retention")
        ]
        
        for (policy, description) in testCases {
            var preferences = BackupPreferences()
            preferences.retentionPolicy = policy
            
            #expect(preferences.retentionPolicy == policy)
            #expect(preferences.retentionPolicy.description == description)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup preferences for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let preferences1 = BackupPreferences(
            compressionLevel: .maximum,
            parallelOperations: 4,
            bandwidthLimit: 1024 * 1024,
            notificationsEnabled: false,
            autoBackupEnabled: true,
            retentionPolicy: .custom(days: 30),
            excludeSystemFiles: false,
            excludeHiddenFiles: false
        )
        
        let preferences2 = BackupPreferences(
            compressionLevel: .maximum,
            parallelOperations: 4,
            bandwidthLimit: 1024 * 1024,
            notificationsEnabled: false,
            autoBackupEnabled: true,
            retentionPolicy: .custom(days: 30),
            excludeSystemFiles: false,
            excludeHiddenFiles: false
        )
        
        let preferences3 = BackupPreferences(
            compressionLevel: .default,
            parallelOperations: 2,
            bandwidthLimit: nil,
            notificationsEnabled: true,
            autoBackupEnabled: false,
            retentionPolicy: .default,
            excludeSystemFiles: true,
            excludeHiddenFiles: true
        )
        
        #expect(preferences1 == preferences2)
        #expect(preferences1 != preferences3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup preferences", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Default preferences
            BackupPreferences(),
            // Custom preferences
            BackupPreferences(
                compressionLevel: .maximum,
                parallelOperations: 4,
                bandwidthLimit: 1024 * 1024,
                notificationsEnabled: false,
                autoBackupEnabled: true,
                retentionPolicy: .custom(days: 30),
                excludeSystemFiles: false,
                excludeHiddenFiles: false
            ),
            // Minimal preferences
            BackupPreferences(
                compressionLevel: .none,
                parallelOperations: 1,
                bandwidthLimit: nil,
                notificationsEnabled: false,
                autoBackupEnabled: false,
                retentionPolicy: .none,
                excludeSystemFiles: false,
                excludeHiddenFiles: false
            )
        ]
        
        for preferences in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(preferences)
            let decoded = try decoder.decode(BackupPreferences.self, from: data)
            
            // Then
            #expect(decoded.compressionLevel == preferences.compressionLevel)
            #expect(decoded.parallelOperations == preferences.parallelOperations)
            #expect(decoded.bandwidthLimit == preferences.bandwidthLimit)
            #expect(decoded.notificationsEnabled == preferences.notificationsEnabled)
            #expect(decoded.autoBackupEnabled == preferences.autoBackupEnabled)
            #expect(decoded.retentionPolicy == preferences.retentionPolicy)
            #expect(decoded.excludeSystemFiles == preferences.excludeSystemFiles)
            #expect(decoded.excludeHiddenFiles == preferences.excludeHiddenFiles)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup preferences properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid preferences
            (4, UInt64(1024 * 1024), 30, true),
            // Invalid parallel operations
            (0, UInt64(1024 * 1024), 30, false),
            // Invalid retention days
            (4, UInt64(1024 * 1024), -1, false),
            // Valid without bandwidth limit
            (4, nil, 30, true)
        ]
        
        for (operations, bandwidth, retentionDays, isValid) in testCases {
            let preferences = BackupPreferences(
                compressionLevel: .default,
                parallelOperations: operations,
                bandwidthLimit: bandwidth,
                notificationsEnabled: true,
                autoBackupEnabled: false,
                retentionPolicy: .custom(days: retentionDays),
                excludeSystemFiles: true,
                excludeHiddenFiles: true
            )
            
            if isValid {
                #expect(preferences.isValid)
            } else {
                #expect(!preferences.isValid)
            }
        }
    }
}
