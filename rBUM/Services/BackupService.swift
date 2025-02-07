//
//  BackupService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 7 February 2025
//

import Core
import Foundation

/// Service for managing backup operations.
///
/// BackupService provides a comprehensive solution for:
/// 1. Creating and managing backups
/// 2. Initialising and managing repositories
/// 3. Managing backup state and health
/// 4. Handling file operations safely
/// 5. Measuring and monitoring operations
///
/// Example usage:
/// ```swift
/// let backupService = BackupService(
///     resticService: resticService,
///     keychainService: keychainService
/// )
///
/// // Create a backup
/// try await backupService.createBackup(
///     to: repository,
///     paths: ["/path/to/backup"],
///     tags: ["important"]
/// )
///
/// // List snapshots
/// let snapshots = try await backupService.listSnapshots(in: repository)
/// ```
public final class BackupService: BaseSandboxedService, BackupServiceProtocol, HealthCheckable, Measurable,
    @unchecked Sendable {
    // MARK: - Properties

    /// Service for executing Restic commands
    internal let resticService: ResticServiceProtocol
    
    /// Service for managing secure credentials
    internal let keychainService: KeychainService
    
    /// Queue for managing backup operations
    internal let operationQueue: OperationQueue
    
    /// Actor for managing backup state
    internal let backupState = BackupState()
    
    /// Indicates whether the service is healthy
    @objc public private(set) var isHealthy: Bool = true
    
    /// Hash value for the service
    @objc override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(ObjectIdentifier(resticService))
        hasher.combine(ObjectIdentifier(keychainService))
        return hasher.finalize()
    }
    
    /// Description of the service
    @objc override public var description: String {
        "BackupService"
    }

    // MARK: - Initialization

    /// Initialises a new BackupService with the required dependencies.
    ///
    /// - Parameters:
    ///   - resticService: Service for executing Restic commands
    ///   - keychainService: Service for managing secure credentials
    public init(resticService: ResticServiceProtocol, keychainService: KeychainService) {
        self.resticService = resticService
        self.keychainService = keychainService
        
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        
        let logger = OSLogger(category: "backup")
        super.init(logger: logger)
    }
}

// MARK: - State Management

extension BackupService {
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

    private func updateHealthStatus() async {
        let isEmpty = await backupState.isEmpty
        let resticHealthy = await (try? resticService.performHealthCheck()) ?? false
        isHealthy = isEmpty && resticHealthy
    }
}
