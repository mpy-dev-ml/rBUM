//
//  BackupService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 30/01/2025.
//

import Core
import Foundation

/// Service for managing backup operations
public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable, Measurable,
    @unchecked Sendable
{
    // MARK: - Properties

    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainService
    private let operationQueue: OperationQueue

    private actor BackupState {
        var activeBackups: Set<UUID> = []
        var cachedHealthStatus: Bool = true

        func insert(_ id: UUID) {
            activeBackups.insert(id)
            updateCachedHealth()
        }

        func remove(_ id: UUID) {
            activeBackups.remove(id)
            updateCachedHealth()
        }

        var isEmpty: Bool {
            activeBackups.isEmpty
        }

        private func updateCachedHealth() {
            cachedHealthStatus = activeBackups.isEmpty
        }
    }

    private let backupState = BackupState()

    @objc override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(ObjectIdentifier(resticService))
        hasher.combine(ObjectIdentifier(keychainService))
        return hasher.finalize()
    }

    @objc override public var description: String {
        "BackupService"
    }

    @objc public private(set) var isHealthy: Bool = true

    public func updateHealthStatus() async {
        let isEmpty = await backupState.isEmpty
        let resticHealthy = await (try? resticService.performHealthCheck()) ?? false
        isHealthy = isEmpty && resticHealthy
    }

    // MARK: - Initialization

    public init(resticService: ResticServiceProtocol, keychainService: KeychainService) {
        self.resticService = resticService
        self.keychainService = keychainService
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        let logger = OSLogger(category: "backup")

        // Create a temporary security service for bootstrapping
        let tempSecurityService = SecurityService(logger: logger, xpcService: MockResticXPCService())

        // Now create the real XPC service with the temporary security service
        let xpcService = ResticXPCService(logger: logger, securityService: tempSecurityService)

        // Finally create the real security service with the real XPC service
        let securityService = SecurityService(logger: logger, xpcService: xpcService as! ResticXPCServiceProtocol)

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - BackupServiceProtocol Implementation

    public func initializeRepository(_ repository: Repository) async throws {
        try await measure("Initialize Repository") {
            try await resticService.initializeRepository(at: URL(fileURLWithPath: repository.path))
        }
    }

    public func createBackup(to repository: Repository, paths: [String], tags _: [String]?) async throws {
        let backupId = UUID()

        try await measure("Create Backup") {
            // Track backup operation
            await backupState.insert(backupId)

            defer {
                Task {
                    await backupState.remove(backupId)
                }
            }

            let configuration = BackupConfiguration(
                source: URL(fileURLWithPath: paths.first!),
                destination: URL(fileURLWithPath: repository.path),
                excludes: [],
                tags: []
            )

            try await handleBackupOperation(
                source: BackupSource(url: configuration.source, metadata: nil),
                destination: repository,
                configuration: configuration
            )

            logger.info("Backup completed to \(repository.path)", file: #file, function: #function, line: #line)
        }
    }

    private func handleBackupOperation(
        source: BackupSource,
        destination: Repository,
        configuration: BackupConfiguration
    ) async throws {
        let operationId = UUID()
        
        do {
            // Start operation
            try await startBackupOperation(operationId, source: source, destination: destination)
            
            // Validate prerequisites
            try await validateBackupPrerequisites(source: source, destination: destination)
            
            // Prepare backup
            let backupData = try await prepareBackupData(source: source, configuration: configuration)
            
            // Execute backup
            try await executeBackup(backupData, to: destination, with: configuration)
            
            // Complete operation
            try await completeBackupOperation(operationId, success: true)
            
        } catch {
            // Handle failure
            try await completeBackupOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    private func startBackupOperation(
        _ id: UUID,
        source: BackupSource,
        destination: Repository
    ) async throws {
        // Record operation start
        let operation = BackupOperation(
            id: id,
            source: source,
            destination: destination,
            timestamp: Date(),
            status: .inProgress
        )
        operationRecorder.recordOperation(operation)
        
        // Log operation start
        logger.info("Starting backup operation", metadata: [
            "operation": .string(id.uuidString),
            "source": .string(source.url.path),
            "destination": .string(destination.url?.path ?? "unknown")
        ])
    }
    
    private func validateBackupPrerequisites(
        source: BackupSource,
        destination: Repository
    ) async throws {
        // Validate source access
        try await validateSourceAccess(source)
        
        // Validate destination access
        try await validateDestinationAccess(destination)
        
        // Validate available space
        try await validateAvailableSpace(for: source, in: destination)
    }
    
    private func validateSourceAccess(_ source: BackupSource) async throws {
        // Check source exists
        guard source.url.isFileURL else {
            throw BackupError.invalidSource("Source must be a file URL")
        }
        
        guard try await securityService.validateAccess(to: source.url) else {
            throw BackupError.accessDenied("Cannot access backup source")
        }
        
        guard try await securityService.validateReadAccess(to: source.url) else {
            throw BackupError.accessDenied("Cannot read from backup source")
        }
    }
    
    private func validateDestinationAccess(_ destination: Repository) async throws {
        guard let url = destination.url else {
            throw BackupError.invalidDestination("Destination URL is missing")
        }
        
        guard try await securityService.validateAccess(to: url) else {
            throw BackupError.accessDenied("Cannot access backup destination")
        }
        
        guard try await securityService.validateWriteAccess(to: url) else {
            throw BackupError.accessDenied("Cannot write to backup destination")
        }
    }
    
    private func validateAvailableSpace(
        for source: BackupSource,
        in destination: Repository
    ) async throws {
        guard let destinationURL = destination.url else {
            throw BackupError.invalidDestination("Destination URL is missing")
        }
        
        // Get source size
        let sourceSize = try await fileManager.size(of: source.url)
        
        // Get available space
        let availableSpace = try await fileManager.availableSpace(at: destinationURL)
        
        // Check if enough space (including buffer)
        let requiredSpace = sourceSize + minimumFreeSpace
        guard availableSpace >= requiredSpace else {
            throw BackupError.insufficientSpace(
                "Insufficient space at destination. Required: \(requiredSpace), Available: \(availableSpace)"
            )
        }
    }
    
    private func prepareBackupData(
        source: BackupSource,
        configuration: BackupConfiguration
    ) async throws -> BackupData {
        // Create backup data
        var backupData = BackupData(
            source: source,
            timestamp: Date(),
            files: [],
            totalSize: 0,
            metadata: [:]
        )
        
        // Scan source directory
        let files = try await scanSourceDirectory(source.url)
        
        // Filter files based on configuration
        let filteredFiles = try await filterFiles(
            files,
            using: configuration.filters
        )
        
        // Calculate total size
        let totalSize = try await calculateTotalSize(of: filteredFiles)
        
        // Update backup data
        backupData.files = filteredFiles
        backupData.totalSize = totalSize
        backupData.metadata = try await collectMetadata(for: source)
        
        return backupData
    }
    
    private func scanSourceDirectory(_ url: URL) async throws -> [URL] {
        var files: [URL] = []
        
        if try await fileManager.isDirectory(at: url) {
            // Recursively scan directory
            let contents = try await fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            for item in contents {
                if try await fileManager.isDirectory(at: item) {
                    let subFiles = try await scanSourceDirectory(item)
                    files.append(contentsOf: subFiles)
                } else {
                    files.append(item)
                }
            }
        } else {
            // Single file
            files.append(url)
        }
        
        return files
    }
    
    private func filterFiles(
        _ files: [URL],
        using filters: [BackupFilter]
    ) async throws -> [URL] {
        var filteredFiles = files
        
        for filter in filters {
            switch filter {
            case .exclude(let pattern):
                filteredFiles = filteredFiles.filter { !$0.path.contains(pattern) }
            case .include(let pattern):
                filteredFiles = filteredFiles.filter { $0.path.contains(pattern) }
            case .extension(let ext):
                filteredFiles = filteredFiles.filter { $0.pathExtension == ext }
            case .size(let comparison, let size):
                filteredFiles = try await filterFilesBySize(
                    filteredFiles,
                    comparison: comparison,
                    size: size
                )
            case .date(let comparison, let date):
                filteredFiles = try await filterFilesByDate(
                    filteredFiles,
                    comparison: comparison,
                    date: date
                )
            }
        }
        
        return filteredFiles
    }
    
    private func filterFilesBySize(
        _ files: [URL],
        comparison: SizeComparison,
        size: UInt64
    ) async throws -> [URL] {
        var filtered: [URL] = []
        
        for file in files {
            let fileSize = try await fileManager.size(of: file)
            
            switch comparison {
            case .lessThan:
                if fileSize < size {
                    filtered.append(file)
                }
            case .greaterThan:
                if fileSize > size {
                    filtered.append(file)
                }
            case .equalTo:
                if fileSize == size {
                    filtered.append(file)
                }
            }
        }
        
        return filtered
    }
    
    private func filterFilesByDate(
        _ files: [URL],
        comparison: DateComparison,
        date: Date
    ) async throws -> [URL] {
        var filtered: [URL] = []
        
        for file in files {
            let attributes = try await fileManager.attributesOfItem(atPath: file.path)
            guard let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }
            
            switch comparison {
            case .before:
                if modificationDate < date {
                    filtered.append(file)
                }
            case .after:
                if modificationDate > date {
                    filtered.append(file)
                }
            case .on:
                if Calendar.current.isDate(modificationDate, inSameDayAs: date) {
                    filtered.append(file)
                }
            }
        }
        
        return filtered
    }
    
    private func calculateTotalSize(of files: [URL]) async throws -> UInt64 {
        var totalSize: UInt64 = 0
        
        for file in files {
            let size = try await fileManager.size(of: file)
            totalSize += size
        }
        
        return totalSize
    }
    
    private func collectMetadata(for source: BackupSource) async throws -> [String: String] {
        var metadata: [String: String] = [:]
        
        // Add basic metadata
        metadata["source_path"] = source.url.path
        metadata["backup_time"] = ISO8601DateFormatter().string(from: Date())
        metadata["hostname"] = Host.current().localizedName ?? "unknown"
        
        // Add platform info
        metadata["os_version"] = ProcessInfo.processInfo.operatingSystemVersionString
        
        // Add custom metadata
        if let customMetadata = source.metadata {
            metadata.merge(customMetadata) { current, _ in current }
        }
        
        return metadata
    }
    
    private func executeBackup(
        _ data: BackupData,
        to destination: Repository,
        with configuration: BackupConfiguration
    ) async throws {
        // Get repository credentials
        let credentials = try await credentialsService.getCredentials(for: destination)
        
        // Create environment
        var environment = ProcessInfo.processInfo.environment
        environment["RESTIC_PASSWORD"] = credentials.password
        environment["RESTIC_REPOSITORY"] = destination.url?.path
        
        // Build backup command
        var arguments = ["backup"]
        
        // Add compression if enabled
        if configuration.compression {
            arguments.append("--compression=max")
        }
        
        // Add tags
        for tag in configuration.tags {
            arguments.append("--tag=\(tag)")
        }
        
        // Add files
        arguments.append(contentsOf: data.files.map { $0.path })
        
        // Execute backup
        let result = try await processExecutor.execute(
            command: "restic",
            arguments: arguments,
            environment: environment
        )
        
        guard result.exitCode == 0 else {
            throw BackupError.backupFailed(result.error)
        }
    }
    
    private func completeBackupOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Update operation status
        let status: BackupOperationStatus = success ? .completed : .failed
        operationRecorder.updateOperation(id, status: status, error: error)
        
        // Log completion
        logger.info("Completed backup operation", metadata: [
            "operation": .string(id.uuidString),
            "status": .string(status.rawValue),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none")
        ])
        
        // Update metrics
        if success {
            metrics.recordSuccess()
        } else {
            metrics.recordFailure()
        }
        
        // Send notification
        let notification: Notification.Name = success ? .backupCompleted : .backupFailed
        notificationCenter.post(
            name: notification,
            object: nil,
            userInfo: [
                "operation": id,
                "status": status,
                "error": error as Any
            ]
        )
    }

    public func listSnapshots(in _: Repository) async throws -> [ResticSnapshot] {
        try await measure("List Snapshots") {
            let snapshotIds = try await resticService.listSnapshots()

            return snapshotIds.map { id in
                ResticSnapshot(
                    id: id,
                    time: Date(),
                    hostname: Host.current().localizedName ?? "Unknown",
                    tags: nil,
                    paths: []
                )
            }
        }
    }

    public func restore(
        snapshot _: ResticSnapshot,
        from repository: Repository,
        paths _: [String],
        to target: String
    ) async throws {
        try await measure("Restore Snapshot") {
            try await resticService.restore(
                from: URL(fileURLWithPath: repository.path),
                to: URL(fileURLWithPath: target)
            )
        }
    }

    // MARK: - HealthCheckable Implementation

    public func performHealthCheck() async throws -> Bool {
        await measure("Backup Service Health Check") {
            await updateHealthStatus()
            return isHealthy
        }
    }
}

// MARK: - Backup Errors

public enum BackupError: LocalizedError {
    case invalidRepository
    case backupFailed
    case restoreFailed
    case snapshotListFailed
    case sourceNotFound
    case destinationNotFound
    case insufficientSpace
    case sourceAccessDenied
    case destinationAccessDenied
    case executionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidRepository:
            "Invalid repository configuration"
        case .backupFailed:
            "Failed to create backup"
        case .restoreFailed:
            "Failed to restore from snapshot"
        case .snapshotListFailed:
            "Failed to list snapshots"
        case .sourceNotFound:
            "Source directory not found"
        case .destinationNotFound:
            "Destination directory not found"
        case .insufficientSpace:
            "Insufficient space available for backup"
        case .sourceAccessDenied:
            "Access denied to source directory"
        case .destinationAccessDenied:
            "Access denied to destination directory"
        case .executionFailed(let error):
            "Backup execution failed: \(error.localizedDescription)"
        }
    }
}

struct BackupConfiguration {
    let source: URL
    let destination: URL
    let excludes: [String]
    let tags: [String]
}

struct BackupOperation {
    let id: UUID
    let source: URL
    let destination: URL
    let excludes: [String]
    let tags: [String]
    let startTime: Date
}

enum BackupResultStatus {
    case completed
    case failed
}

struct BackupResult {
    let operationId: UUID
    let status: BackupResultStatus
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let error: Error?
}

struct BackupSource {
    let url: URL
    let metadata: [String: String]?
}

struct BackupData {
    let source: BackupSource
    let timestamp: Date
    let files: [URL]
    let totalSize: UInt64
    let metadata: [String: String]
}

enum BackupFilter {
    case exclude(String)
    case include(String)
    case extension(String)
    case size(SizeComparison, UInt64)
    case date(DateComparison, Date)
}

enum SizeComparison {
    case lessThan
    case greaterThan
    case equalTo
}

enum DateComparison {
    case before
    case after
    case on
}

enum BackupOperationStatus {
    case inProgress
    case completed
    case failed
}
