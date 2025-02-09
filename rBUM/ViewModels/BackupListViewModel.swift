//
//  BackupListViewModel.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation
import SwiftUI

/// View model for managing the list of backups across all repositories
@MainActor
final class BackupListViewModel: ObservableObject {
    // MARK: - Types
    
    /// Represents the state of a backup operation
    enum BackupState {
        case idle
        case inProgress(progress: Double)
        case completed(date: Date)
        case failed(error: Error)
    }
    
    /// Represents a backup operation with its associated data
    struct BackupOperation: Identifiable {
        let id: String
        let repository: Repository
        let sources: [URL]
        let tags: [String]
        let startTime: Date
        var state: BackupState
        var lastUpdated: Date
    }
    
    // MARK: - Published Properties
    
    /// List of all backup operations
    @Published private(set) var backupOperations: [BackupOperation] = []
    
    /// List of available repositories
    @Published private(set) var repositories: [Repository] = []
    
    /// Currently selected backup operation
    @Published var selectedOperation: BackupOperation?
    
    /// Whether to show the new backup sheet
    @Published var showNewBackupSheet = false
    
    /// Filter for backup operations
    @Published var filter: Filter = .all
    
    /// Search text for filtering operations
    @Published var searchText = ""
    
    // MARK: - Private Properties
    
    private let backupService: BackupServiceProtocol
    private let repositoryService: RepositoryServiceProtocol
    private let logger: LoggerProtocol
    private var sourceTracker: BackupSourceTracker?
    private var trackedSources: [BackupSource] = []
    private var pendingChanges: [String: Bool] = [:]
    private let fileMonitor = FileMonitor()
    private var sourceStreams: [String: FSEventStream] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the view model with required services
    /// - Parameters:
    ///   - backupService: Service for managing backup operations
    ///   - repositoryService: Service for accessing repositories
    ///   - logger: Logger for recording events
    init(
        backupService: BackupServiceProtocol,
        repositoryService: RepositoryServiceProtocol,
        logger: LoggerProtocol
    ) {
        self.backupService = backupService
        self.repositoryService = repositoryService
        self.logger = logger
        setupSourceTracking()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSourceChange(_:)),
            name: .backupSourceChanged,
            object: nil
        )
    }
    
    deinit {
        stopSourceTracking()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Load all backup operations and repositories
    func loadBackupOperations() async {
        do {
            async let repos = repositoryService.listRepositories()
            async let snapshots = repositories.first.map { try await backupService.listSnapshots(in: $0) } ?? []
            
            let (loadedRepos, loadedSnapshots) = try await (repos, snapshots)
            
            // Fetch sources for each snapshot concurrently
            var operations: [BackupOperation] = []
            try await withThrowingTaskGroup(of: (String, [URL]).self) { group in
                for snapshot in loadedSnapshots {
                    group.addTask {
                        let sources = try await self.fetchSourcesForSnapshot(snapshot.id)
                        return (snapshot.id, sources)
                    }
                }
                
                // Collect results as they complete
                for try await (snapshotId, sources) in group {
                    if let snapshot = loadedSnapshots.first(where: { $0.id == snapshotId }) {
                        operations.append(BackupOperation(
                            id: snapshot.id,
                            repository: loadedRepos.first ?? Repository(name: "Unknown", url: nil),
                            sources: sources,
                            tags: snapshot.tags,
                            startTime: snapshot.time,
                            state: .completed(date: snapshot.time),
                            lastUpdated: snapshot.time
                        ))
                    }
                }
            }
            
            await MainActor.run {
                repositories = loadedRepos
                backupOperations = operations
            }
        } catch {
            logger.error("Failed to load backup operations: \(error.localizedDescription)")
        }
    }
    
    /// Fetches sources for a given snapshot ID
    /// - Parameter snapshotId: ID of the snapshot to fetch sources for
    /// - Returns: Array of source URLs
    private func fetchSourcesForSnapshot(_ snapshotId: String) async throws -> [URL] {
        guard let snapshot = try await backupService.getSnapshot(id: snapshotId) else {
            return []
        }
        
        // Convert source paths to URLs
        return snapshot.sourcePaths.compactMap { URL(fileURLWithPath: $0) }
    }
    
    /// Start a new backup operation
    /// - Parameters:
    ///   - repository: Repository to backup to
    ///   - sources: Source URLs to backup
    ///   - tags: Optional tags for the backup
    func startBackup(
        to repository: Repository,
        sources: [URL],
        tags: [String]
    ) async {
        do {
            try await backupService.createBackup(
                to: repository,
                paths: sources.map(\.path),
                tags: tags
            )
            
            // Refresh the list after creating a backup
            await loadBackupOperations()
        } catch {
            logger.error("Failed to start backup: \(error.localizedDescription)")
        }
    }
    
    /// Cancel a backup operation
    func cancelBackup() async {
        guard let currentBackup = activeBackup else { return }
        await backupService.cancelCurrentOperation()
        activeBackup = nil
        backupQueue.remove(currentBackup)
    }
    
    // MARK: - Private Methods
    
    private func mapBackupState(_ state: BackupState) -> BackupState {
        state
    }
    
    private func trackBackupSource(_ source: BackupSource) {
        guard !trackedSources.contains(source) else { return }
        trackedSources.append(source)
        
        // Start monitoring the source for changes
        do {
            try fileMonitor.startMonitoring(path: source.path) { [weak self] event in
                self?.handleFileEvent(event, for: source)
            }
        } catch {
            logger.error("Failed to start monitoring source: \(error.localizedDescription)")
        }
    }
    
    private func handleFileEvent(_ event: FileEvent, for source: BackupSource) {
        switch event {
        case .modified:
            pendingChanges[source.id] = true
            objectWillChange.send()
        case .deleted:
            trackedSources.removeAll { $source.id == $0.id }
            pendingChanges.removeValue(forKey: source.id)
            objectWillChange.send()
        }
    }
    
    /// Tracks changes in backup sources using FSEvents
    private func setupSourceTracking() {
        guard let sources = try? backupService.getBackupSources() else { return }
        
        for source in sources {
            let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                { _, _, numEvents, eventPaths, eventFlags, _ in
                    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                    
                    for eventIndex in 0..<numEvents {
                        let path = paths[eventIndex]
                        let flags = eventFlags[eventIndex]
                        let isModified = flags.contains(.itemModified) || 
                            flags.contains(.itemCreated) || 
                            flags.contains(.itemRemoved)
                        
                        if isModified {
                            NotificationCenter.default.post(
                                name: .backupSourceChanged,
                                object: nil,
                                userInfo: ["path": path]
                            )
                        }
                    }
                },
                nil,
                [source.path] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                1.0,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
            )
            
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            
            sourceStreams[source.id] = stream
        }
    }
    
    /// Stops tracking changes for all sources
    private func stopSourceTracking() {
        for stream in sourceStreams.values {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        sourceStreams.removeAll()
    }
    
    /// Updates the backup status when source changes are detected
    @objc private func handleSourceChange(_ notification: Notification) {
        guard let path = notification.userInfo?["path"] as? String else { return }
        
        Task {
            if let source = try? await backupService.getBackupSources().first(where: { $0.path == path }) {
                try? await backupService.getBackupStatus(for: source)
            }
        }
    }
}

// MARK: - Filter

extension BackupListViewModel {
    /// Filter options for backup operations
    enum Filter: String, CaseIterable {
        case all = "All"
        case inProgress = "In Progress"
        case completed = "Completed"
        case failed = "Failed"
        
        var predicate: (BackupOperation) -> Bool {
            switch self {
            case .all:
                return { _ in true }
            case .inProgress:
                return { operation in
                    if case .inProgress = operation.state {
                        return true
                    }
                    return false
                }
            case .completed:
                return { operation in
                    if case .completed = operation.state {
                        return true
                    }
                    return false
                }
            case .failed:
                return { operation in
                    if case .failed = operation.state {
                        return true
                    }
                    return false
                }
            }
        }
    }
}
