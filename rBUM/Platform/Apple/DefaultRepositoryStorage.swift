//
//  DefaultRepositoryStorage.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation
import Core

/// Default repository storage implementation for macOS
final class DefaultRepositoryStorage: RepositoryStorageProtocol {
    // MARK: - Properties
    private let fileManager: FileManagerProtocol
    private let logger: LoggerProtocol
    private let storageURL: URL

    // MARK: - Initialization
    init(
        fileManager: FileManagerProtocol = DefaultFileManager(),
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "RepositoryStorage"),
        storageURL: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.logger = logger

        if let url = storageURL {
            self.storageURL = url
        } else {
            // Get application support directory
            guard let appSupport = try? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                logger.error("Could not access application support directory")
                throw RepositoryError.invalidDirectory
            }

            // Create repositories directory if needed
            self.storageURL = appSupport.appendingPathComponent("Repositories", isDirectory: true)
        }

        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)

        logger.debug("Storage initialised", metadata: ["path": .string(storageURL.path)])
    }

    // MARK: - Repository Management
    func save(_ repository: Repository) async throws {
        logger.debug("Saving repository", metadata: [
            "id": .string(repository.id.uuidString),
            "name": .string(repository.name)
        ])

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(repository)

            let fileURL = storageURL.appendingPathComponent("\(repository.id.uuidString).json")
            try data.write(to: fileURL, options: .atomic)

            logger.info("Saved repository successfully", metadata: [
                "id": .string(repository.id.uuidString)
            ])
        } catch {
            logger.error("Failed to save repository", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw RepositoryError.saveFailed(error)
        }
    }

    func loadAll() async throws -> [Repository] {
        logger.debug("Loading all repositories")

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: storageURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let repositories = try contents
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> Repository? in
                    do {
                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        return try decoder.decode(Repository.self, from: data)
                    } catch {
                        logger.error("Failed to load repository", metadata: [
                            "path": .string(url.path),
                            "error": .string(error.localizedDescription)
                        ])
                        return nil
                    }
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

            logger.info("Loaded repositories", metadata: [
                "count": .string("\(repositories.count)")
            ])
            return repositories

        } catch {
            logger.error("Failed to load repositories", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw RepositoryError.loadFailed(error)
        }
    }

    func delete(_ repository: Repository) async throws {
        logger.debug("Deleting repository", metadata: [
            "id": .string(repository.id.uuidString),
            "name": .string(repository.name)
        ])

        do {
            let fileURL = storageURL.appendingPathComponent("\(repository.id.uuidString).json")
            try fileManager.removeItem(at: fileURL)

            logger.info("Deleted repository successfully", metadata: [
                "id": .string(repository.id.uuidString)
            ])
        } catch {
            logger.error("Failed to delete repository", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw RepositoryError.deleteFailed(error)
        }
    }

    func updateStatus(_ repository: Repository, status: RepositoryStatus) async throws {
        logger.debug("Updating repository status", metadata: [
            "id": .string(repository.id.uuidString),
            "status": .string("\(status)")
        ])

        do {
            var updated = repository
            updated.status = status
            updated.lastAccessed = Date()
            try await save(updated)

            logger.info("Updated repository status successfully", metadata: [
                "id": .string(repository.id.uuidString)
            ])
        } catch {
            logger.error("Failed to update repository status", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw RepositoryError.updateFailed(error)
        }
    }
}

// MARK: - Repository Errors
enum RepositoryError: LocalizedError {
    case invalidDirectory
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)
    case updateFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            return "Could not access repository storage directory"
        case .saveFailed(let error):
            return "Failed to save repository: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load repositories: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete repository: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update repository status: \(error.localizedDescription)"
        }
    }
}
