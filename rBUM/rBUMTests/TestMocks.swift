//
//  TestMocks.swift
//  rBUMTests
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Foundation
@testable import rBUM

enum TestMocks {
    final class MockRepositoryStorage: RepositoryStorageProtocol {
        var repositories: [Repository] = []
        var storeError: Error?
        var retrieveError: Error?
        var deleteError: Error?
        var existsError: Error?
        var existsResult: Bool = false
        
        func list() throws -> [Repository] {
            if let error = retrieveError {
                throw error
            }
            return repositories
        }
        
        func store(_ repository: Repository) throws {
            if let error = storeError {
                throw error
            }
            repositories.append(repository)
        }
        
        func retrieve(forId id: UUID) throws -> Repository? {
            if let error = retrieveError {
                throw error
            }
            return repositories.first { $0.id == id }
        }
        
        func delete(forId id: UUID) throws {
            if let error = deleteError {
                throw error
            }
            repositories.removeAll { $0.id == id }
        }
        
        func exists(atPath path: URL, excludingId: UUID?) throws -> Bool {
            if let error = existsError {
                throw error
            }
            return existsResult
        }
    }
    
    final class MockResticCommandService: ResticCommandServiceProtocol {
        func checkRepository(_ repository: URL, withPassword password: String) async throws -> rBUM.RepositoryStatus {
            <#code#>
        }
        
        var initError: Error?
        var checkError: Error?
        var backupError: Error?
        var listSnapshotsError: Error?
        var pruneError: Error?
        
        func initializeRepository(at path: URL, password: String) async throws {
            if let error = initError {
                throw error
            }
        }
        
        func checkRepository(at path: URL, credentials: RepositoryCredentials) async throws {
            if let error = checkError {
                throw error
            }
        }
        
        func createBackup(
            paths: [URL],
            to repository: Repository,
            credentials: RepositoryCredentials,
            tags: [String]?,
            onProgress: ((BackupProgress) -> Void)?,
            onStatusChange: ((BackupStatus) -> Void)?
        ) async throws {
            if let error = backupError {
                throw error
            }
            
            // Simulate backup progress
            onStatusChange?(.preparing)
            
            // Simulate some progress updates
            let progress = BackupProgress(
                totalFiles: 10,
                processedFiles: 5,
                totalBytes: 1024,
                processedBytes: 512,
                currentFile: "/test/file.txt",
                estimatedSecondsRemaining: 10,
                startTime: Date()
            )
            onProgress?(progress)
            onStatusChange?(.backing(progress))
            
            // Simulate completion
            onStatusChange?(.completed)
        }
        
        func listSnapshots(in repository: Repository, credentials: RepositoryCredentials) async throws -> [Snapshot] {
            if let error = listSnapshotsError {
                throw error
            }
            return []
        }
        
        func pruneSnapshots(
            in repository: Repository,
            credentials: RepositoryCredentials,
            keepLast: Int?,
            keepDaily: Int?,
            keepWeekly: Int?,
            keepMonthly: Int?,
            keepYearly: Int?
        ) async throws {
            if let error = pruneError {
                throw error
            }
        }
    }
    
    final class MockRepositoryCreationService: RepositoryCreationServiceProtocol {
        var createResult: Repository?
        var importResult: Repository?
        var createError: Error?
        var importError: Error?
        
        func createRepository(name: String, path: URL, password: String) async throws -> Repository {
            if let error = createError {
                throw error
            }
            return createResult ?? Repository(name: name, path: path)
        }
        
        func importRepository(name: String, path: URL, password: String) async throws -> Repository {
            if let error = importError {
                throw error
            }
            return importResult ?? Repository(name: name, path: path)
        }
    }
    
    final class MockCredentialsManager: CredentialsManagerProtocol {
        var storeError: Error?
        var retrieveError: Error?
        var updateError: Error?
        var deleteError: Error?
        var getPasswordError: Error?
        var storedCredentials: [UUID: RepositoryCredentials] = [:]
        
        func store(_ credentials: RepositoryCredentials) async throws {
            if let error = storeError {
                throw error
            }
            storedCredentials[credentials.repositoryId] = credentials
        }
        
        func retrieve(forId id: UUID) async throws -> RepositoryCredentials {
            if let error = retrieveError {
                throw error
            }
            guard let credentials = storedCredentials[id] else {
                throw CredentialsError.notFound
            }
            return credentials
        }
        
        func update(_ credentials: RepositoryCredentials) async throws {
            if let error = updateError {
                throw error
            }
            storedCredentials[credentials.repositoryId] = credentials
        }
        
        func delete(forId id: UUID) async throws {
            if let error = deleteError {
                throw error
            }
            storedCredentials.removeValue(forKey: id)
        }
        
        func getPassword(forRepositoryId id: UUID) async throws -> String {
            if let error = getPasswordError {
                throw error
            }
            guard let credentials = storedCredentials[id] else {
                throw CredentialsError.notFound
            }
            return credentials.password
        }
        
        func createCredentials(id: UUID, path: String, password: String) -> RepositoryCredentials {
            RepositoryCredentials(
                repositoryId: id,
                password: password,
                repositoryPath: path
            )
        }
    }
}
