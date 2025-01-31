//
//  BackupSettingsTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupSettingsTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup settings with default values", tags: ["basic", "model"])
    func testDefaultInitialization() throws {
        // When
        let settings = BackupSettings()
        
        // Then
        #expect(settings.resticPath == "/usr/local/bin/restic")
        #expect(settings.cachePath.lastPathComponent == "Cache")
        #expect(settings.tempPath.lastPathComponent == "Temp")
        #expect(settings.logPath.lastPathComponent == "Logs")
        #expect(settings.maxLogSize == 10 * 1024 * 1024) // 10 MB
        #expect(settings.maxLogFiles == 10)
        #expect(settings.logLevel == .info)
        #expect(settings.useSystemKeychain)
    }
    
    @Test("Initialize backup settings with custom values", tags: ["basic", "model"])
    func testCustomInitialization() throws {
        // Given
        let resticPath = "/opt/bin/restic"
        let cachePath = URL(fileURLWithPath: "/custom/cache")
        let tempPath = URL(fileURLWithPath: "/custom/temp")
        let logPath = URL(fileURLWithPath: "/custom/logs")
        let maxLogSize: UInt64 = 20 * 1024 * 1024 // 20 MB
        let maxLogFiles = 20
        let logLevel = LogLevel.debug
        let useSystemKeychain = false
        
        // When
        let settings = BackupSettings(
            resticPath: resticPath,
            cachePath: cachePath,
            tempPath: tempPath,
            logPath: logPath,
            maxLogSize: maxLogSize,
            maxLogFiles: maxLogFiles,
            logLevel: logLevel,
            useSystemKeychain: useSystemKeychain
        )
        
        // Then
        #expect(settings.resticPath == resticPath)
        #expect(settings.cachePath == cachePath)
        #expect(settings.tempPath == tempPath)
        #expect(settings.logPath == logPath)
        #expect(settings.maxLogSize == maxLogSize)
        #expect(settings.maxLogFiles == maxLogFiles)
        #expect(settings.logLevel == logLevel)
        #expect(settings.useSystemKeychain == useSystemKeychain)
    }
    
    // MARK: - Path Tests
    
    @Test("Handle path validations", tags: ["model", "path"])
    func testPathValidations() throws {
        let testCases = [
            // Valid paths
            ("/usr/local/bin/restic", "/cache", "/temp", "/logs", true),
            ("/opt/restic", "~/cache", "~/temp", "~/logs", true),
            // Invalid restic path
            ("", "/cache", "/temp", "/logs", false),
            // Invalid cache path
            ("/usr/local/bin/restic", "", "/temp", "/logs", false),
            // Invalid temp path
            ("/usr/local/bin/restic", "/cache", "", "/logs", false),
            // Invalid log path
            ("/usr/local/bin/restic", "/cache", "/temp", "", false),
            // Paths with spaces
            ("/usr/local/bin/restic", "/cache path", "/temp path", "/log path", true),
            // Paths with special characters
            ("/usr/local/bin/restic", "/cache!@#", "/temp$%^", "/logs&*()", true)
        ]
        
        for (resticPath, cachePath, tempPath, logPath, isValid) in testCases {
            let settings = BackupSettings(
                resticPath: resticPath,
                cachePath: URL(fileURLWithPath: cachePath),
                tempPath: URL(fileURLWithPath: tempPath),
                logPath: URL(fileURLWithPath: logPath)
            )
            
            if isValid {
                #expect(settings.isValid)
            } else {
                #expect(!settings.isValid)
            }
        }
    }
    
    // MARK: - Log Level Tests
    
    @Test("Handle log levels", tags: ["model", "logging"])
    func testLogLevels() throws {
        let testCases: [(LogLevel, String)] = [
            (.error, "Error"),
            (.warning, "Warning"),
            (.info, "Information"),
            (.debug, "Debug"),
            (.trace, "Trace")
        ]
        
        for (level, description) in testCases {
            var settings = BackupSettings()
            settings.logLevel = level
            
            #expect(settings.logLevel == level)
            #expect(settings.logLevel.description == description)
        }
    }
    
    // MARK: - Log Size Tests
    
    @Test("Handle log size limits", tags: ["model", "logging"])
    func testLogSizeLimits() throws {
        let testCases: [(UInt64, String)] = [
            (1024, "1.0 KB"),
            (1024 * 1024, "1.0 MB"),
            (10 * 1024 * 1024, "10.0 MB"),
            (1024 * 1024 * 1024, "1.0 GB")
        ]
        
        for (size, formattedSize) in testCases {
            var settings = BackupSettings()
            settings.maxLogSize = size
            
            #expect(settings.maxLogSize == size)
            #expect(settings.formattedMaxLogSize == formattedSize)
        }
    }
    
    // MARK: - Log File Count Tests
    
    @Test("Handle log file count limits", tags: ["model", "logging"])
    func testLogFileCountLimits() throws {
        let testCases = [
            // Valid counts
            1, 5, 10, 20, 50,
            // Invalid counts (should be clamped)
            0, -1, 101, 1000
        ]
        
        for count in testCases {
            var settings = BackupSettings()
            settings.maxLogFiles = count
            
            let expectedValue = max(1, min(count, 100))
            #expect(settings.maxLogFiles == expectedValue)
        }
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare backup settings for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let settings1 = BackupSettings(
            resticPath: "/test/restic",
            cachePath: URL(fileURLWithPath: "/test/cache"),
            tempPath: URL(fileURLWithPath: "/test/temp"),
            logPath: URL(fileURLWithPath: "/test/logs"),
            maxLogSize: 1024 * 1024,
            maxLogFiles: 10,
            logLevel: .debug,
            useSystemKeychain: false
        )
        
        let settings2 = BackupSettings(
            resticPath: "/test/restic",
            cachePath: URL(fileURLWithPath: "/test/cache"),
            tempPath: URL(fileURLWithPath: "/test/temp"),
            logPath: URL(fileURLWithPath: "/test/logs"),
            maxLogSize: 1024 * 1024,
            maxLogFiles: 10,
            logLevel: .debug,
            useSystemKeychain: false
        )
        
        let settings3 = BackupSettings(
            resticPath: "/other/restic",
            cachePath: URL(fileURLWithPath: "/other/cache"),
            tempPath: URL(fileURLWithPath: "/other/temp"),
            logPath: URL(fileURLWithPath: "/other/logs")
        )
        
        #expect(settings1 == settings2)
        #expect(settings1 != settings3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup settings", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Default settings
            BackupSettings(),
            // Custom settings
            BackupSettings(
                resticPath: "/test/restic",
                cachePath: URL(fileURLWithPath: "/test/cache"),
                tempPath: URL(fileURLWithPath: "/test/temp"),
                logPath: URL(fileURLWithPath: "/test/logs"),
                maxLogSize: 1024 * 1024,
                maxLogFiles: 10,
                logLevel: .debug,
                useSystemKeychain: false
            ),
            // Minimal settings
            BackupSettings(
                resticPath: "/usr/bin/restic",
                cachePath: URL(fileURLWithPath: "/cache"),
                tempPath: URL(fileURLWithPath: "/temp"),
                logPath: URL(fileURLWithPath: "/logs")
            )
        ]
        
        for settings in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(settings)
            let decoded = try decoder.decode(BackupSettings.self, from: data)
            
            // Then
            #expect(decoded.resticPath == settings.resticPath)
            #expect(decoded.cachePath == settings.cachePath)
            #expect(decoded.tempPath == settings.tempPath)
            #expect(decoded.logPath == settings.logPath)
            #expect(decoded.maxLogSize == settings.maxLogSize)
            #expect(decoded.maxLogFiles == settings.maxLogFiles)
            #expect(decoded.logLevel == settings.logLevel)
            #expect(decoded.useSystemKeychain == settings.useSystemKeychain)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup settings properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid settings
            ("/test/restic", 1024 * 1024, 10, true),
            // Invalid restic path
            ("", 1024 * 1024, 10, false),
            // Invalid log size
            ("/test/restic", 0, 10, false),
            // Invalid log file count
            ("/test/restic", 1024 * 1024, 0, false),
            // All valid maximums
            ("/test/restic", UInt64.max, 100, true)
        ]
        
        for (resticPath, logSize, logFiles, isValid) in testCases {
            let settings = BackupSettings(
                resticPath: resticPath,
                cachePath: URL(fileURLWithPath: "/test/cache"),
                tempPath: URL(fileURLWithPath: "/test/temp"),
                logPath: URL(fileURLWithPath: "/test/logs"),
                maxLogSize: logSize,
                maxLogFiles: logFiles
            )
            
            if isValid {
                #expect(settings.isValid)
            } else {
                #expect(!settings.isValid)
            }
        }
    }
}
