import Foundation
import os.log

// MARK: - Repository Discovery Extension

extension ResticService: RepositoryDiscoveryXPCProtocol {
    public func scanLocation(_ url: URL, recursive: Bool, reply: @escaping ([URL]?, Error?) -> Void) {
        logger.info("Scanning location: \(url.path), recursive: \(recursive)")

        Task {
            do {
                let urls = try await scanForRepositories(at: url, recursive: recursive)
                reply(urls, nil)
            } catch {
                logger.error("Repository scan failed: \(error.localizedDescription)")
                reply(nil, error)
            }
        }
    }

    public func verifyRepository(at url: URL, reply: @escaping (Bool, Error?) -> Void) {
        logger.info("Verifying repository at: \(url.path)")

        Task {
            do {
                let isValid = try await verifyResticRepository(at: url)
                reply(isValid, nil)
            } catch {
                logger.error("Repository verification failed: \(error.localizedDescription)")
                reply(false, error)
            }
        }
    }

    public func getRepositoryMetadata(at url: URL, reply: @escaping ([String: Any]?, Error?) -> Void) {
        logger.info("Fetching metadata for repository at: \(url.path)")

        Task {
            do {
                let metadata = try await fetchRepositoryMetadata(for: url)
                reply(metadata, nil)
            } catch {
                logger.error("Metadata fetch failed: \(error.localizedDescription)")
                reply(nil, error)
            }
        }
    }

    public func indexRepository(at url: URL, reply: @escaping (Error?) -> Void) {
        logger.info("Indexing repository at: \(url.path)")

        Task {
            do {
                try await indexRepositoryContents(at: url)
                reply(nil)
            } catch {
                logger.error("Repository indexing failed: \(error.localizedDescription)")
                reply(error)
            }
        }
    }

    public func cancelOperations() {
        logger.info("Cancelling repository discovery operations")
        // Cancel any ongoing operations
        currentOperations.forEach { $0.cancel() }
    }
}

// MARK: - Private Implementation

private extension ResticService {
    /// Array to track current operations for cancellation
    private var currentOperations: [Process] {
        get { synchronized(self) { _currentOperations } }
        set { synchronized(self) { _currentOperations = newValue } }
    }

    private var _currentOperations: [Process] = []

    func scanForRepositories(at url: URL, recursive: Bool) async throws -> [URL] {
        var repositories: [URL] = []

        // Check if the current directory is a repository
        if try await isResticRepository(at: url) {
            repositories.append(url)
        }

        guard recursive else { return repositories }

        // Get directory contents
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isReadableKey]
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip unreadable items
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let isDirectory = resourceValues.isDirectory,
                  let isReadable = resourceValues.isReadable,
                  isReadable else { continue }

            if isDirectory {
                if try await isResticRepository(at: fileURL) {
                    repositories.append(fileURL)
                    // Skip subdirectories of repositories
                    enumerator?.skipDescendants()
                }
            }
        }

        return repositories
    }

    func isResticRepository(at url: URL) async throws -> Bool {
        // Check for config file and data directory
        let configPath = url.appendingPathComponent("config")
        let dataPath = url.appendingPathComponent("data")

        guard FileManager.default.fileExists(atPath: configPath.path),
              FileManager.default.fileExists(atPath: dataPath.path)
        else {
            return false
        }

        // Verify repository structure using restic
        return try await verifyResticRepository(at: url)
    }

    func verifyResticRepository(at url: URL) async throws -> Bool {
        let process = Process()
        process.executableURL = resticPath
        process.arguments = ["cat", "config", "-r", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        synchronized(self) {
            currentOperations.append(process)
        }

        defer {
            synchronized(self) {
                currentOperations.removeAll { $0 == process }
            }
        }

        try process.run()
        return await process.terminationStatus == 0
    }

    func fetchRepositoryMetadata(for url: URL) async throws -> [String: Any] {
        var metadata: [String: Any] = [:]

        // Get repository size
        if let size = try? await calculateRepositorySize(at: url) {
            metadata["size"] = size
        }

        // Get last modified date
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modificationDate = attributes[.modificationDate] as? Date
        {
            metadata["lastModified"] = modificationDate
        }

        // Get snapshot count using restic
        if let snapshotCount = try? await getSnapshotCount(for: url) {
            metadata["snapshotCount"] = snapshotCount
        }

        return metadata
    }

    func calculateRepositorySize(at url: URL) async throws -> UInt64 {
        var size: UInt64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                      let fileSize = resourceValues.totalFileAllocatedSize else { continue }
                size += UInt64(fileSize)
            }
        }

        return size
    }

    func getSnapshotCount(for url: URL) async throws -> Int {
        let process = Process()
        process.executableURL = resticPath
        process.arguments = ["snapshots", "--json", "-r", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        synchronized(self) {
            currentOperations.append(process)
        }

        defer {
            synchronized(self) {
                currentOperations.removeAll { $0 == process }
            }
        }

        try process.run()
        let data = try await pipe.fileHandleForReading.readToEnd() ?? Data()

        guard process.terminationStatus == 0,
              let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return 0
        }

        return json.count
    }

    func indexRepositoryContents(at url: URL) async throws {
        logger.info("Starting repository indexing at: \(url.path)")

        // Get list of snapshots
        let process = Process()
        process.executableURL = resticPath
        process.arguments = ["snapshots", "--json", "-r", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        synchronized(self) {
            currentOperations.append(process)
        }

        defer {
            synchronized(self) {
                currentOperations.removeAll { $0 == process }
            }
        }

        try process.run()
        let snapshotData = try await pipe.fileHandleForReading.readToEnd() ?? Data()

        guard process.terminationStatus == 0,
              let snapshots = try JSONSerialization.jsonObject(with: snapshotData) as? [[String: Any]]
        else {
            throw RepositoryDiscoveryError.discoveryFailed("Failed to read snapshots")
        }

        // Index each snapshot's contents
        for snapshot in snapshots {
            try await indexSnapshot(snapshotID: snapshot["id"] as? String ?? "", at: url)
        }

        logger.info("Repository indexing completed successfully")
    }

    private func indexSnapshot(snapshotID: String, at url: URL) async throws {
        let process = Process()
        process.executableURL = resticPath
        process.arguments = ["ls", "--json", "-r", url.path, snapshotID]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        synchronized(self) {
            currentOperations.append(process)
        }

        defer {
            synchronized(self) {
                currentOperations.removeAll { $0 == process }
            }
        }

        try process.run()
        let listData = try await pipe.fileHandleForReading.readToEnd() ?? Data()

        guard process.terminationStatus == 0,
              let files = try JSONSerialization.jsonObject(with: listData) as? [[String: Any]]
        else {
            throw RepositoryDiscoveryError.discoveryFailed("Failed to list snapshot contents")
        }

        // Store the file list in the index
        // Note: In a real implementation, we would store this in a proper search index
        // For now, we just log the count of files found
        logger.info("Indexed \(files.count) files from snapshot \(snapshotID)")
    }
}
