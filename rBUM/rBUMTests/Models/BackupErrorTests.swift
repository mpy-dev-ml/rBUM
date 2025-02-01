//
//  BackupErrorTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for BackupError functionality
struct BackupErrorTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let userDefaults: TestMocks.MockUserDefaults
        let notificationCenter: TestMocks.MockNotificationCenter
        
        init() {
            self.userDefaults = TestMocks.MockUserDefaults()
            self.notificationCenter = TestMocks.MockNotificationCenter()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            userDefaults.reset()
            notificationCenter.reset()
        }
    }
    
    // MARK: - Error Creation Tests
    
    @Test("Create backup errors with different types", tags: ["error", "init"])
    func testErrorCreation() throws {
        // Given: Different error scenarios
        let testCases: [(BackupError, String)] = [
            // Network errors
            (MockData.Error.networkError, "Network connection failed"),
            (MockData.Error.timeoutError, "Operation timed out"),
            (MockData.Error.connectionError, "Failed to connect to repository"),
            
            // Permission errors
            (MockData.Error.permissionError, "Insufficient permissions"),
            (MockData.Error.accessDeniedError, "Access denied to backup location"),
            
            // Repository errors
            (MockData.Error.repositoryError, "Repository operation failed"),
            (MockData.Error.repositoryNotFoundError, "Repository not found"),
            (MockData.Error.repositoryCorruptError, "Repository is corrupted"),
            
            // Configuration errors
            (MockData.Error.configurationError, "Invalid configuration"),
            (MockData.Error.invalidPathError, "Invalid backup path"),
            
            // Credential errors
            (MockData.Error.credentialError, "Invalid credentials"),
            (MockData.Error.authenticationError, "Authentication failed"),
            
            // System errors
            (MockData.Error.systemError, "System error occurred"),
            (MockData.Error.diskSpaceError, "Insufficient disk space"),
            
            // Restic errors
            (MockData.Error.resticError, "Restic command failed"),
            (MockData.Error.snapshotError, "Failed to create snapshot")
        ]
        
        // When/Then: Test each error case
        for (error, expectedMessage) in testCases {
            #expect(error.localizedDescription.contains(expectedMessage))
            #expect(error.isRecoverable == MockData.Error.recoverableErrors.contains(error))
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle error recovery options", tags: ["error", "recovery"])
    func testErrorRecovery() throws {
        // Given: Different error recovery scenarios
        let testCases: [(BackupError, [String])] = [
            // Network errors with recovery options
            (MockData.Error.networkError, ["Retry connection", "Check network settings"]),
            (MockData.Error.timeoutError, ["Retry operation", "Increase timeout"]),
            
            // Permission errors with recovery options
            (MockData.Error.permissionError, ["Request permissions", "Use different location"]),
            
            // Repository errors with recovery options
            (MockData.Error.repositoryError, ["Check repository", "Repair repository"]),
            
            // Non-recoverable errors
            (MockData.Error.systemError, []),
            (MockData.Error.diskSpaceError, ["Free up space"])
        ]
        
        // When/Then: Test recovery options
        for (error, expectedOptions) in testCases {
            let recoveryOptions = error.recoveryOptions
            #expect(recoveryOptions.count == expectedOptions.count)
            for (option, expectedOption) in zip(recoveryOptions, expectedOptions) {
                #expect(option == expectedOption)
            }
        }
    }
    
    // MARK: - Error Classification Tests
    
    @Test("Classify errors by type", tags: ["error", "classification"])
    func testErrorClassification() throws {
        // Given: Different error types
        let testCases: [(BackupError, BackupErrorType)] = [
            (MockData.Error.networkError, .network),
            (MockData.Error.permissionError, .permission),
            (MockData.Error.repositoryError, .repository),
            (MockData.Error.configurationError, .configuration),
            (MockData.Error.credentialError, .credential),
            (MockData.Error.systemError, .system),
            (MockData.Error.resticError, .restic)
        ]
        
        // When/Then: Test error classification
        for (error, expectedType) in testCases {
            #expect(error.type == expectedType)
        }
    }
    
    // MARK: - Error Persistence Tests
    
    @Test("Test error persistence", tags: ["error", "persistence"])
    func testErrorPersistence() throws {
        // Given: Context and test errors
        let context = TestContext()
        let testErrors = [
            MockData.Error.networkError,
            MockData.Error.permissionError,
            MockData.Error.repositoryError
        ]
        
        for error in testErrors {
            // When: Storing error
            context.userDefaults.set(error.persistenceData, forKey: "LastBackupError")
            
            // Then: Error can be retrieved
            if let data = context.userDefaults.object(forKey: "LastBackupError") as? Data,
               let retrievedError = try? BackupError.fromPersistenceData(data) {
                #expect(retrievedError == error)
                #expect(retrievedError.localizedDescription == error.localizedDescription)
            } else {
                throw TestFailure("Failed to persist and retrieve error")
            }
        }
    }
    
    // MARK: - Notification Tests
    
    @Test("Test error notifications", tags: ["error", "notification"])
    func testErrorNotifications() throws {
        // Given: Context and test error
        let context = TestContext()
        let error = MockData.Error.networkError
        
        // When: Posting error notification
        NotificationCenter.default.post(
            name: .backupErrorOccurred,
            object: nil,
            userInfo: ["error": error]
        )
        
        // Then: Notification is received with correct error
        #expect(context.notificationCenter.postCalled)
        if let notification = context.notificationCenter.lastNotification,
           let notificationError = notification.userInfo?["error"] as? BackupError {
            #expect(notificationError == error)
        } else {
            throw TestFailure("Failed to receive error notification")
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle error edge cases", tags: ["error", "edge"])
    func testEdgeCases() throws {
        // Test empty error message
        let emptyError = BackupError(code: .unknown, message: "")
        #expect(emptyError.localizedDescription == "Unknown error occurred")
        
        // Test maximum length message
        let longMessage = String(repeating: "a", count: 1000)
        let longError = BackupError(code: .unknown, message: longMessage)
        #expect(longError.localizedDescription.count <= 500)
        
        // Test nil recovery options
        let noRecoveryError = BackupError(code: .unknown, message: "No recovery", recoveryOptions: nil)
        #expect(noRecoveryError.recoveryOptions.isEmpty)
        
        // Test invalid persistence data
        let invalidData = Data([0x00, 0x01, 0x02])
        do {
            _ = try BackupError.fromPersistenceData(invalidData)
            throw TestFailure("Expected error for invalid data")
        } catch {
            // Expected error
        }
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

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenter {
    var postCalled = false
    var lastNotification: Notification?
    
    override func post(_ notification: Notification) {
        postCalled = true
        lastNotification = notification
    }
    
    func reset() {
        postCalled = false
        lastNotification = nil
    }
}
