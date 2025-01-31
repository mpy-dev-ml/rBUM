//
//  RepositoryCreationServiceTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
@testable import rBUM

/// Tests for RepositoryCreationService functionality
struct RepositoryCreationServiceTests {
    // MARK: - Test Context
    
    /// Test environment with test data
    struct TestContext {
        let resticService: MockResticService
        let notificationCenter: MockNotificationCenter
        let fileManager: MockFileManager
        let securityService: MockSecurityService
        let keychain: MockKeychain
        let progressTracker: MockProgressTracker
        
        init() {
            self.resticService = MockResticService()
            self.notificationCenter = MockNotificationCenter()
            self.fileManager = MockFileManager()
            self.securityService = MockSecurityService()
            self.keychain = MockKeychain()
            self.progressTracker = MockProgressTracker()
        }
        
        /// Reset all mocks to initial state
        func reset() {
            resticService.reset()
            notificationCenter.reset()
            fileManager.reset()
            securityService.reset()
            keychain.reset()
            progressTracker.reset()
        }
        
        /// Create test repository creation service
        func createService() -> RepositoryCreationService {
            RepositoryCreationService(
                resticService: resticService,
                notificationCenter: notificationCenter,
                fileManager: fileManager,
                securityService: securityService,
                keychain: keychain,
                progressTracker: progressTracker
            )
        }
    }
    
    // MARK: - Basic Creation Tests
    
    @Test("Test basic repository creation", tags: ["repository", "create"])
    func testBasicRepositoryCreation() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.creationData
        
        // Test repository creation
        for testCase in testCases {
            // Create repository
            let repository = try service.createRepository(
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
            #expect(context.notificationCenter.postNotificationCalled)
            
            context.reset()
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Test repository creation validation", tags: ["repository", "validate"])
    func testRepositoryCreationValidation() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.validationData
        
        // Test repository validation
        for testCase in testCases {
            do {
                // Attempt creation
                _ = try service.createRepository(
                    name: testCase.name,
                    path: testCase.path,
                    password: testCase.password
                )
                
                if !testCase.expectedValid {
                    throw TestFailure("Expected validation error for invalid data")
                }
            } catch {
                if testCase.expectedValid {
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
    
    @Test("Test repository path handling", tags: ["repository", "path"])
    func testRepositoryPathHandling() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.pathData
        
        // Test path handling
        for testCase in testCases {
            do {
                // Create repository with path
                let repository = try service.createRepository(
                    name: "Test Repository",
                    path: testCase.path,
                    password: "test-password"
                )
                
                // Verify path handling
                #expect(repository.path == testCase.expectedPath)
                #expect(context.fileManager.createDirectoryCalled == testCase.shouldCreateDirectory)
                
                if testCase.shouldCreateDirectory {
                    #expect(context.fileManager.lastCreatedPath == testCase.expectedPath)
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
    
    @Test("Test repository password handling", tags: ["repository", "password"])
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
                #expect(context.keychain.lastSavedPassword == testCase.expectedStoredPassword)
                #expect(context.securityService.validatePasswordCalled)
                
                let storedPassword = try context.keychain.getPassword(for: repository.id)
                #expect(storedPassword == testCase.expectedStoredPassword)
            } catch {
                if testCase.shouldSucceed {
                    throw TestFailure("Unexpected password handling error: \(error)")
                }
            }
            
            context.reset()
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    @Test("Test repository creation progress tracking", tags: ["repository", "progress"])
    func testProgressTracking() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let testCases = MockData.Repository.progressData
        
        // Test progress tracking
        for testCase in testCases {
            // Create repository with progress tracking
            _ = try service.createRepository(
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
    
    @Test("Test repository creation error handling", tags: ["repository", "error"])
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
    
    @Test("Test concurrent repository creation", tags: ["repository", "concurrent"])
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
    
    @Test("Test repository creation performance", tags: ["repository", "performance"])
    func testPerformance() throws {
        // Given: Repository creation service
        let context = TestContext()
        let service = context.createService()
        
        let startTime = Date()
        
        // Create multiple repositories
        for i in 0..<10 {
            _ = try service.createRepository(
                name: "Performance Test \(i)",
                path: URL(fileURLWithPath: "/test/path/\(i)"),
                password: "test-password"
            )
        }
        
        let endTime = Date()
        
        // Verify performance
        let timeInterval = endTime.timeIntervalSince(startTime)
        #expect(timeInterval < 5.0) // Should complete in under 5 seconds
        
        // Test individual operation performance
        let operationStart = Date()
        _ = try service.createRepository(
            name: "Performance Test",
            path: URL(fileURLWithPath: "/test/path"),
            password: "test-password"
        )
        let operationEnd = Date()
        
        let operationInterval = operationEnd.timeIntervalSince(operationStart)
        #expect(operationInterval < 0.5) // Single operation should be fast
    }
}
