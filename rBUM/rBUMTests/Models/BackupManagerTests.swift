//
//  BackupManagerTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupManagerTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup manager with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        
        // When
        let manager = BackupManager(id: id)
        
        // Then
        #expect(manager.id == id)
        #expect(manager.repositories.isEmpty)
        #expect(manager.queues.isEmpty)
        #expect(manager.monitors.isEmpty)
        #expect(manager.isActive == false)
    }
    
    @Test("Initialize backup manager with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let repositories = [
            Repository(id: UUID(), name: "Test Repo", path: URL(fileURLWithPath: "/test/repo"))
        ]
        let queues = [
            BackupQueue(id: UUID(), name: "Test Queue")
        ]
        let monitors = [
            BackupMonitor(id: UUID(), repositoryId: repositories[0].id)
        ]
        let isActive = true
        
        // When
        let manager = BackupManager(
            id: id,
            repositories: repositories,
            queues: queues,
            monitors: monitors,
            isActive: isActive
        )
        
        // Then
        #expect(manager.id == id)
        #expect(manager.repositories == repositories)
        #expect(manager.queues == queues)
        #expect(manager.monitors == monitors)
        #expect(manager.isActive == isActive)
    }
    
    // MARK: - Repository Tests
    
    @Test("Handle repository management", tags: ["model", "repository"])
    func testRepositoryManagement() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/repo")
        )
        
        // Test adding repository
        manager.addRepository(repository)
        #expect(manager.repositories.count == 1)
        #expect(manager.repositories.contains(repository))
        
        // Test updating repository
        var updatedRepo = repository
        updatedRepo.name = "Updated Repo"
        manager.updateRepository(updatedRepo)
        #expect(manager.repositories.first?.name == "Updated Repo")
        
        // Test removing repository
        manager.removeRepository(repository.id)
        #expect(manager.repositories.isEmpty)
    }
    
    // MARK: - Queue Tests
    
    @Test("Handle queue management", tags: ["model", "queue"])
    func testQueueManagement() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let queue = BackupQueue(
            id: UUID(),
            name: "Test Queue"
        )
        
        // Test adding queue
        manager.addQueue(queue)
        #expect(manager.queues.count == 1)
        #expect(manager.queues.contains(queue))
        
        // Test updating queue
        var updatedQueue = queue
        updatedQueue.name = "Updated Queue"
        manager.updateQueue(updatedQueue)
        #expect(manager.queues.first?.name == "Updated Queue")
        
        // Test removing queue
        manager.removeQueue(queue.id)
        #expect(manager.queues.isEmpty)
    }
    
    // MARK: - Monitor Tests
    
    @Test("Handle monitor management", tags: ["model", "monitor"])
    func testMonitorManagement() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/repo")
        )
        manager.addRepository(repository)
        
        let monitor = BackupMonitor(
            id: UUID(),
            repositoryId: repository.id
        )
        
        // Test adding monitor
        manager.addMonitor(monitor)
        #expect(manager.monitors.count == 1)
        #expect(manager.monitors.contains(monitor))
        
        // Test updating monitor
        var updatedMonitor = monitor
        updatedMonitor.isActive = true
        manager.updateMonitor(updatedMonitor)
        #expect(manager.monitors.first?.isActive == true)
        
        // Test removing monitor
        manager.removeMonitor(monitor.id)
        #expect(manager.monitors.isEmpty)
    }
    
    // MARK: - Operation Tests
    
    @Test("Handle backup operations", tags: ["model", "operations"])
    func testBackupOperations() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/repo")
        )
        manager.addRepository(repository)
        
        let queue = BackupQueue(
            id: UUID(),
            name: "Test Queue"
        )
        manager.addQueue(queue)
        
        // Test creating backup operation
        let operation = manager.createBackupOperation(
            repositoryId: repository.id,
            sourcePath: URL(fileURLWithPath: "/test/source"),
            queueId: queue.id
        )
        
        #expect(operation != nil)
        #expect(operation?.repositoryId == repository.id)
        #expect(manager.queues.first?.operations.contains(operation!) == true)
        
        // Test starting operation
        manager.startOperation(operation!.id)
        let startedOp = manager.findOperation(operation!.id)
        #expect(startedOp?.status == .running)
        
        // Test completing operation
        manager.completeOperation(operation!.id)
        let completedOp = manager.findOperation(operation!.id)
        #expect(completedOp?.status == .completed)
    }
    
    // MARK: - Schedule Tests
    
    @Test("Handle backup schedules", tags: ["model", "schedule"])
    func testBackupSchedules() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/repo")
        )
        manager.addRepository(repository)
        
        let schedule = BackupSchedule(
            id: UUID(),
            repositoryId: repository.id,
            frequency: .daily,
            time: Date()
        )
        
        // Test adding schedule
        manager.addSchedule(schedule)
        #expect(manager.schedules.count == 1)
        #expect(manager.schedules.contains(schedule))
        
        // Test next backup time
        let nextBackup = manager.getNextBackupTime(repositoryId: repository.id)
        #expect(nextBackup != nil)
        #expect(nextBackup! >= Date())
        
        // Test due backups
        let dueBackups = manager.getDueBackups()
        #expect(dueBackups.isEmpty || dueBackups.contains { $0.repositoryId == repository.id })
    }
    
    // MARK: - Statistics Tests
    
    @Test("Track backup statistics", tags: ["model", "statistics"])
    func testBackupStatistics() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/repo")
        )
        manager.addRepository(repository)
        
        // Create and complete some operations
        for _ in 0..<5 {
            let operation = BackupOperation(
                id: UUID(),
                repositoryId: repository.id,
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test/source"),
                status: .completed
            )
            manager.recordOperation(operation)
        }
        
        // Test statistics
        let stats = manager.getStatistics(repositoryId: repository.id)
        #expect(stats != nil)
        #expect(stats?.totalOperations == 5)
        #expect(stats?.successfulOperations == 5)
        #expect(stats?.failedOperations == 0)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle backup errors", tags: ["model", "error"])
    func testErrorHandling() throws {
        // Given
        var manager = BackupManager(id: UUID())
        let repository = Repository(
            id: UUID(),
            name: "Test Repo",
            path: URL(fileURLWithPath: "/test/repo")
        )
        manager.addRepository(repository)
        
        let operation = BackupOperation(
            id: UUID(),
            repositoryId: repository.id,
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test/source")
        )
        
        // Test error recording
        manager.recordError(.repositoryNotFound, forOperation: operation.id)
        let updatedOp = manager.findOperation(operation.id)
        #expect(updatedOp?.error == .repositoryNotFound)
        #expect(updatedOp?.status == .failed)
        
        // Test error statistics
        let stats = manager.getStatistics(repositoryId: repository.id)
        #expect(stats?.failedOperations == 1)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup manager", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Empty manager
            BackupManager(id: UUID()),
            // Manager with components
            BackupManager(
                id: UUID(),
                repositories: [
                    Repository(
                        id: UUID(),
                        name: "Test Repo",
                        path: URL(fileURLWithPath: "/test/repo")
                    )
                ],
                queues: [
                    BackupQueue(id: UUID(), name: "Test Queue")
                ],
                monitors: [
                    BackupMonitor(id: UUID(), repositoryId: UUID())
                ],
                isActive: true
            )
        ]
        
        for manager in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(manager)
            let decoded = try decoder.decode(BackupManager.self, from: data)
            
            // Then
            #expect(decoded.id == manager.id)
            #expect(decoded.repositories == manager.repositories)
            #expect(decoded.queues == manager.queues)
            #expect(decoded.monitors == manager.monitors)
            #expect(decoded.isActive == manager.isActive)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup manager properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid manager
            (UUID(), true, true),
            // Invalid repository paths
            (UUID(), true, false),
            // Invalid monitor configuration
            (UUID(), false, true)
        ]
        
        for (id, validRepos, validMonitors) in testCases {
            var manager = BackupManager(id: id)
            
            if validRepos {
                manager.addRepository(Repository(
                    id: UUID(),
                    name: "Test Repo",
                    path: URL(fileURLWithPath: "/test/repo")
                ))
            }
            
            if validMonitors {
                manager.addMonitor(BackupMonitor(
                    id: UUID(),
                    repositoryId: manager.repositories.first?.id ?? UUID()
                ))
            }
            
            #expect(manager.isValid == (validRepos && validMonitors))
        }
    }
}
