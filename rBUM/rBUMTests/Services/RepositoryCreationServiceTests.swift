//
//  RepositoryCreationServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM
import Foundation
import TestMocksModule
import Security

/// Tests for RepositoryCreationService functionality
struct RepositoryCreationServiceTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let resticService: TestMocksModule.TestMocks.MockResticService
        let notificationCenter: TestMocksModule.TestMocks.MockNotificationCenter
        let fileManager: TestMocksModule.TestMocks.MockFileManager
        let securityService: TestMocksModule.TestMocks.MockSecurityService
        let keychain: TestMocksModule.TestMocks.MockKeychain
        let progressTracker: TestMocksModule.TestMocks.MockProgressTracker
        let bookmarkManager: TestMocksModule.TestMocks.MockBookmarkManager
        
        init() {
            self.resticService = TestMocksModule.TestMocks.MockResticService()
            self.notificationCenter = TestMocksModule.TestMocks.MockNotificationCenter()
            self.fileManager = TestMocksModule.TestMocks.MockFileManager()
            self.securityService = TestMocksModule.TestMocks.MockSecurityService()
            self.keychain = TestMocksModule.TestMocks.MockKeychain()
            self.progressTracker = TestMocksModule.TestMocks.MockProgressTracker()
            self.bookmarkManager = TestMocksModule.TestMocks.MockBookmarkManager()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            resticService.reset()
            notificationCenter.reset()
            fileManager.reset()
            securityService.reset()
            keychain.reset()
            progressTracker.reset()
            bookmarkManager.reset()
        }
        
        /// Create test repository creation service
        func createService() -> RepositoryCreationService {
            RepositoryCreationService(
                resticService: resticService as! ResticCommandServiceProtocol, repositoryStorage: <#any RepositoryStorageProtocol#>,
                notificationCenter: notificationCenter,
                fileManager: fileManager,
                securityService: securityService,
                keychain: keychain,
                progressTracker: progressTracker,
                bookmarkManager: bookmarkManager
            )
        }
    }
    
    // MARK: - Test Types
    
    typealias TestMocks = TestMocksModule.TestMocks
    
    // MARK: - Test Data
    
    enum MockData {
        struct Repository {
            static let creationData: [(
                name: String,
                path: String,
                password: String,
                shouldSucceed: Bool,
                expectedError: RepositoryCreationError?
            )] = [
                ("Test Repo", "/test/path", "password123", true, nil),
                ("", "/test/path", "password123", false, .invalidName),
                ("Test Repo", "", "password123", false, .invalidPath),
                ("Test Repo", "/test/path", "", false, .invalidPassword)
            ]
            
            static let validationData: [(
                name: String,
                path: String,
                password: String,
                shouldSucceed: Bool,
                expectedError: RepositoryCreationError?
            )] = [
                ("Valid Repo", "/valid/path", "validpass", true, nil),
                ("Invalid Repo", "/invalid/path", "invalidpass", false, .validationFailed)
            ]
            
            static let pathData: [(
                name: String,
                path: String,
                password: String,
                shouldSucceed: Bool,
                expectedError: RepositoryCreationError?
            )] = [
                ("Path Test", "/test/path", "password123", true, nil),
                ("Path Test", "/invalid/path", "password123", false, .pathError)
            ]
            
            static let passwordData: [(
                name: String,
                path: String,
                password: String,
                shouldSucceed: Bool,
                expectedError: RepositoryCreationError?
            )] = [
                ("Password Test", "/test/path", "strongpass", true, nil),
                ("Password Test", "/test/path", "weak", false, .passwordTooWeak)
            ]
            
            static let progressData: [(
                name: String,
                path: String,
                password: String,
                expectedProgress: Double
            )] = [
                ("Progress Test", "/test/path", "password123", 1.0)
            ]
            
            static let errorCases: [(
                name: String,
                path: String,
                password: String,
                error: Error,
                expectedError: RepositoryCreationError
            )] = [
                ("Error Test", "/test/path", "password123", NSError(domain: "test", code: 1), .unknown)
            ]
            
            static let concurrentData: [(
                name: String,
                path: String,
                password: String,
                shouldSucceed: Bool,
                expectedError: RepositoryCreationError?
            )] = [
                ("Concurrent Test 1", "/test/path1", "password123", true, nil),
                ("Concurrent Test 2", "/test/path2", "password123", true, nil)
            ]
            
            static let sandboxData: [(
                name: String,
                path: String,
                password: String,
                shouldSucceed: Bool,
                expectedError: RepositoryCreationError?
            )] = [
                ("Sandbox Test", "/test/sandbox/path", "password123", true, nil),
                ("Invalid Sandbox", "/invalid/sandbox/path", "password123", false, .sandboxAccessDenied)
            ]
        }
    }
    
    // MARK: - Basic Creation Tests
    
    @Test("Test basic repository creation", ["repository", "create"] as! TestTrait)
    func testBasicRepositoryCreation() async throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.creationData
        
        // Test repository creation
        for testCase in testCases {
            // Create repository
            let repository = try await service.createRepository(
                name: testCase.name,
                path: testCase.path,
                password: testCase.password
            )
            
            // Verify repository creation
            #expect(repository.id != nil)
            #expect(repository.name == testCase.name)
            #expect(repository.path == testCase.path)
            #expect(context.resticService.initializeRepositoryCalled)
            #expect(context.keychain.savePasswordCalled)
            
            // Then: Verify notification handling
            if testCase.shouldSucceed {
                let notifications = context.notificationCenter.postedNotifications
                #expect(!notifications.isEmpty)
                #expect(notifications.contains { notification in
                    notification.name == .repositoryCreated &&
                    notification.object as? Repository == repository
                })
            }
            
            context.reset()
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Test repository creation validation", ["repository", "validate"] as! TestTrait)
    func testRepositoryCreationValidation() async throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.validationData
        
        // Test repository validation
        for testCase in testCases {
            do {
                // Attempt creation
                _ = try await service.createRepository(
                    name: testCase.name,
                    path: testCase.path,
                    password: testCase.password
                )
                
                if !testCase.shouldSucceed {
                    throw TestFailure("Expected validation error for invalid data")
                }
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected validation error: \(error)")
                }
                
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryValidationError)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Path Tests
    
    @Test("Test repository path handling", ["repository", "path"] as! TestTrait)
    func testRepositoryPathHandling() async throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.pathData
        
        // Test path handling
        for testCase in testCases {
            do {
                // Create repository with path
                let repository = try await service.createRepository(
                    name: "Test Repository",
                    path: testCase.path,
                    password: "test-password"
                )
                
                // Verify path handling
                #expect(repository.path == testCase.path)
                #expect(context.fileManager.createDirectoryCalled == testCase.shouldSucceed)
                
                if testCase.shouldSucceed {
                    #expect(context.fileManager.lastCreatedPath == testCase.path)
                }
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected path handling error: \(error)")
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Password Tests
    
    @Test("Test repository password handling", ["repository", "password"] as! TestTrait)
    func testRepositoryPasswordHandling() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.passwordData
        
        // Test password handling
        for testCase in testCases {
            do {
                // Create repository with password
                let repository = try service.createRepository(
                    name: "Test Repository",
                    path: URL(fileURLWithPath: "/test/path"),
                    password: testCase.password
                )
                
                // Verify password handling
                #expect(context.keychain.savePasswordCalled)
                #expect(context.keychain.lastSavedPassword == testCase.password)
                #expect(context.securityService.validatePasswordCalled)
                
                let storedPassword = try context.keychain.getPassword(forAccount: repository.id)
                #expect(storedPassword == testCase.password)
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected password handling error: \(error)")
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test("Test repository creation progress tracking", ["repository", "progress"] as! TestTrait)
    func testProgressTracking() async throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.progressData
        
        // Test progress tracking
        for testCase in testCases {
            // Create repository with progress tracking
            _ = try await service.createRepository(
                name: testCase.name,
                path: testCase.path,
                password: testCase.password
            )
            
            // Verify progress tracking
            #expect(context.progressTracker.startProgressCalled)
            #expect(context.progressTracker.updateProgressCalled)
            #expect(context.progressTracker.completeProgressCalled)
            
            let progress = context.progressTracker.lastProgress
            #expect(progress >= 0 && progress <= 1.0)
            
            context.reset()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test repository creation error handling", ["repository", "error"] as! TestTrait)
    func testErrorHandling() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let errorCases = MockData.Repository.errorCases
        
        // Test error handling
        for errorCase in errorCases {
            do {
                // Simulate error condition
                context.resticService.simulateError = errorCase
                
                // Attempt repository creation
                _ = try service.createRepository(
                    name: "Test Repository",
                    path: URL(fileURLWithPath: "/test/path"),
                    password: "test-password"
                )
                
                throw TestFailure("Expected error for \(errorCase)")
            } catch {
                // Verify error handling
                #expect(context.notificationCenter.postNotificationCalled)
                let notification = context.notificationCenter.lastPostedNotification
                #expect(notification?.name == .repositoryError)
                
                // Verify cleanup
                #expect(context.keychain.deletePasswordCalled)
                #expect(context.fileManager.removeItemCalled)
            }
            
            context.reset()
        }
    }
    
    // MARK: - Concurrent Creation Tests
    
    @Test("Test concurrent repository creation", ["repository", "concurrent"] as! TestTrait)
    func testConcurrentCreation() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.concurrentData
        
        // Test concurrent creation
        for testCase in testCases {
            // Create repositories concurrently
            let group = DispatchGroup()
            var repositories: [Repository] = []
            var errors: [Error] = []
            
            for data in testCase.repositories {
                group.enter()
                DispatchQueue.global().async {
                    do {
                        let repository = try service.createRepository(
                            name: data.name,
                            path: data.path,
                            password: data.password
                        )
                        repositories.append(repository)
                    } catch {
                        errors.append(error)
                    }
                    group.leave()
                }
            }
            
            group.wait()
            
            // Verify concurrent creation
            #expect(repositories.count == testCase.expectedSuccessCount)
            #expect(errors.count == testCase.expectedErrorCount)
            
            context.reset()
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Test repository creation performance", ["repository", "performance"] as! TestTrait)
    func testPerformance() async throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let startTime = Date()
        
        // Create multiple repositories
        for i in 0..<10 {
            _ = try await service.createRepository(
                name: "Performance Test \(i)",
                path: "/test/path/\(i)",
                password: "test-password"
            )
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual operation performance
        let operationStart = Date()
        _ = try await service.createRepository(
            name: "Performance Test",
            path: "/test/path",
            password: "test-password"
        )
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.5) // Single operation should be fast
    }
    
    // MARK: - Sandbox Access Tests
    
    @Test("Test sandbox access handling", ["repository", "sandbox"] as! TestTrait)
    func testSandboxAccess() async throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        // When/Then: Test sandbox access cases
        for testCase in MockData.Repository.sandboxData {
            do {
                let repository = try await service.createRepository(
                    name: testCase.name,
                    path: testCase.path,
                    password: testCase.password
                )
                
                if !testCase.shouldSucceed {
                    throw TestFailure("Expected sandbox access error for invalid path")
                }
                
                // Verify bookmark creation
                #expect(context.bookmarkManager.createBookmarkCalled)
                #expect(context.bookmarkManager.lastBookmarkPath == repository.path)
                
                // Verify bookmark resolution
                #expect(context.bookmarkManager.resolveBookmarkCalled)
                #expect(context.bookmarkManager.lastResolvedPath == repository.path)
                
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected sandbox error: \(error)")
                }
                
                if let error = error as? RepositoryCreationError {
                    #expect(error == testCase.expectedError)
                } else {
                    throw TestFailure("Unexpected error type: \(error)")
                }
            }
            
            context.reset()
        }
    }
}
