//
//  BackupQueueTests.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Testing
import Foundation
@testable import rBUM

struct BackupQueueTests {
    // MARK: - Basic Tests
    
    @Test("Initialize backup queue with basic properties", tags: ["basic", "model"])
    func testBasicInitialization() throws {
        // Given
        let id = UUID()
        let name = "Test Queue"
        
        // When
        let queue = BackupQueue(
            id: id,
            name: name
        )
        
        // Then
        #expect(queue.id == id)
        #expect(queue.name == name)
        #expect(queue.operations.isEmpty)
        #expect(queue.status == .idle)
        #expect(queue.currentOperation == nil)
        #expect(queue.maxConcurrentOperations == 1)
    }
    
    @Test("Initialize backup queue with all properties", tags: ["basic", "model"])
    func testFullInitialization() throws {
        // Given
        let id = UUID()
        let name = "Test Queue"
        let operations = [
            BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test1")
            ),
            BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test2")
            )
        ]
        let maxConcurrentOperations = 2
        
        // When
        let queue = BackupQueue(
            id: id,
            name: name,
            operations: operations,
            maxConcurrentOperations: maxConcurrentOperations
        )
        
        // Then
        #expect(queue.id == id)
        #expect(queue.name == name)
        #expect(queue.operations == operations)
        #expect(queue.status == .idle)
        #expect(queue.currentOperation == nil)
        #expect(queue.maxConcurrentOperations == maxConcurrentOperations)
    }
    
    // MARK: - Operation Management Tests
    
    @Test("Handle operation addition and removal", tags: ["model", "operations"])
    func testOperationManagement() throws {
        // Given
        var queue = BackupQueue(
            id: UUID(),
            name: "Test Queue"
        )
        
        let operation1 = BackupOperation(
            id: UUID(),
            repositoryId: UUID(),
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test1")
        )
        
        let operation2 = BackupOperation(
            id: UUID(),
            repositoryId: UUID(),
            type: .backup,
            sourcePath: URL(fileURLWithPath: "/test2")
        )
        
        // Test addition
        queue.addOperation(operation1)
        #expect(queue.operations.count == 1)
        #expect(queue.operations.first == operation1)
        
        queue.addOperation(operation2)
        #expect(queue.operations.count == 2)
        #expect(queue.operations.contains(operation2))
        
        // Test removal
        queue.removeOperation(operation1.id)
        #expect(queue.operations.count == 1)
        #expect(!queue.operations.contains(operation1))
        #expect(queue.operations.contains(operation2))
        
        // Test clear
        queue.clearOperations()
        #expect(queue.operations.isEmpty)
    }
    
    // MARK: - Queue Status Tests
    
    @Test("Handle queue status transitions", tags: ["model", "status"])
    func testStatusTransitions() throws {
        let testCases: [(BackupQueueStatus, BackupQueueStatus, Bool)] = [
            // Valid transitions
            (.idle, .running, true),
            (.running, .paused, true),
            (.paused, .running, true),
            (.running, .idle, true),
            // Invalid transitions
            (.idle, .paused, false),
            (.paused, .idle, false)
        ]
        
        for (fromStatus, toStatus, isValid) in testCases {
            var queue = BackupQueue(
                id: UUID(),
                name: "Test Queue",
                status: fromStatus
            )
            
            if isValid {
                queue.status = toStatus
                #expect(queue.status == toStatus)
            } else {
                queue.status = toStatus
                #expect(queue.status == fromStatus)
            }
        }
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Handle concurrent operations", tags: ["model", "concurrency"])
    func testConcurrency() throws {
        // Given
        var queue = BackupQueue(
            id: UUID(),
            name: "Test Queue",
            maxConcurrentOperations: 2
        )
        
        let operations = (0..<5).map { i in
            BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test\(i)")
            )
        }
        
        // Add operations
        operations.forEach { queue.addOperation($0) }
        
        // Start queue
        queue.status = .running
        
        // Verify concurrent operations
        let runningOperations = queue.operations.filter { $0.status == .running }
        #expect(runningOperations.count <= queue.maxConcurrentOperations)
        
        // Complete some operations
        if var operation = queue.operations.first {
            operation.status = .completed
            queue.updateOperation(operation)
            
            // Verify next operation starts
            let newRunningOperations = queue.operations.filter { $0.status == .running }
            #expect(newRunningOperations.count <= queue.maxConcurrentOperations)
        }
    }
    
    // MARK: - Priority Tests
    
    @Test("Handle operation priorities", tags: ["model", "priority"])
    func testPriorities() throws {
        // Given
        var queue = BackupQueue(
            id: UUID(),
            name: "Test Queue"
        )
        
        let operations = [
            (BackupOperationType.backup, BackupOperationPriority.normal),
            (BackupOperationType.check, BackupOperationPriority.high),
            (BackupOperationType.restore, BackupOperationPriority.urgent)
        ]
        
        // Add operations with different priorities
        operations.forEach { type, priority in
            let operation = BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: type,
                sourcePath: URL(fileURLWithPath: "/test"),
                priority: priority
            )
            queue.addOperation(operation)
        }
        
        // Start queue
        queue.status = .running
        
        // Verify operation order
        let runningOperation = queue.currentOperation
        #expect(runningOperation?.priority == .urgent)
    }
    
    // MARK: - Progress Tests
    
    @Test("Calculate queue progress", tags: ["model", "progress"])
    func testProgress() throws {
        // Given
        var queue = BackupQueue(
            id: UUID(),
            name: "Test Queue"
        )
        
        let operations = [
            (0.0, .pending),
            (0.5, .running),
            (1.0, .completed),
            (0.7, .failed)
        ]
        
        // Add operations with different progress
        operations.forEach { progress, status in
            let operation = BackupOperation(
                id: UUID(),
                repositoryId: UUID(),
                type: .backup,
                sourcePath: URL(fileURLWithPath: "/test"),
                status: status,
                progress: progress
            )
            queue.addOperation(operation)
        }
        
        // Calculate overall progress
        let expectedProgress = operations.reduce(0.0) { sum, tuple in
            sum + (tuple.1 == .failed ? 1.0 : tuple.0)
        } / Double(operations.count)
        
        #expect(queue.progress == expectedProgress)
        #expect(queue.formattedProgress == "\(Int(expectedProgress * 100))%")
    }
    
    // MARK: - Comparison Tests
    
    @Test("Compare queues for equality", tags: ["model", "comparison"])
    func testEquatable() throws {
        let queue1 = BackupQueue(
            id: UUID(),
            name: "Test Queue",
            operations: [
                BackupOperation(
                    id: UUID(),
                    repositoryId: UUID(),
                    type: .backup,
                    sourcePath: URL(fileURLWithPath: "/test")
                )
            ]
        )
        
        let queue2 = BackupQueue(
            id: queue1.id,
            name: "Test Queue",
            operations: queue1.operations
        )
        
        let queue3 = BackupQueue(
            id: UUID(),
            name: "Test Queue",
            operations: queue1.operations
        )
        
        #expect(queue1 == queue2)
        #expect(queue1 != queue3)
    }
    
    // MARK: - Serialization Tests
    
    @Test("Encode and decode backup queue", tags: ["model", "serialization"])
    func testCodable() throws {
        let testCases = [
            // Empty queue
            BackupQueue(
                id: UUID(),
                name: "Empty Queue"
            ),
            // Queue with operations
            BackupQueue(
                id: UUID(),
                name: "Active Queue",
                operations: [
                    BackupOperation(
                        id: UUID(),
                        repositoryId: UUID(),
                        type: .backup,
                        sourcePath: URL(fileURLWithPath: "/test")
                    )
                ],
                status: .running
            ),
            // Queue with concurrent operations
            BackupQueue(
                id: UUID(),
                name: "Concurrent Queue",
                operations: [
                    BackupOperation(
                        id: UUID(),
                        repositoryId: UUID(),
                        type: .backup,
                        sourcePath: URL(fileURLWithPath: "/test1")
                    ),
                    BackupOperation(
                        id: UUID(),
                        repositoryId: UUID(),
                        type: .backup,
                        sourcePath: URL(fileURLWithPath: "/test2")
                    )
                ],
                maxConcurrentOperations: 2
            )
        ]
        
        for queue in testCases {
            // When
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            let data = try encoder.encode(queue)
            let decoded = try decoder.decode(BackupQueue.self, from: data)
            
            // Then
            #expect(decoded.id == queue.id)
            #expect(decoded.name == queue.name)
            #expect(decoded.operations == queue.operations)
            #expect(decoded.status == queue.status)
            #expect(decoded.maxConcurrentOperations == queue.maxConcurrentOperations)
        }
    }
    
    // MARK: - Validation Tests
    
    @Test("Validate backup queue properties", tags: ["model", "validation"])
    func testValidation() throws {
        let testCases = [
            // Valid queue
            (UUID(), "Test Queue", 1, true),
            // Empty name
            (UUID(), "", 1, false),
            // Invalid concurrent operations
            (UUID(), "Test Queue", 0, false),
            (UUID(), "Test Queue", -1, false),
            // Maximum concurrent operations
            (UUID(), "Test Queue", 10, true)
        ]
        
        for (id, name, maxConcurrent, isValid) in testCases {
            let queue = BackupQueue(
                id: id,
                name: name,
                maxConcurrentOperations: maxConcurrent
            )
            
            if isValid {
                #expect(queue.isValid)
            } else {
                #expect(!queue.isValid)
            }
        }
    }
}
