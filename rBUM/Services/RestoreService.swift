import Core
import Foundation

/// Service for managing restore operations
@globalActor actor RestoreActor {
    static let shared = RestoreActor()
}

/// Service responsible for restoring files from Restic snapshots
@RestoreActor
final class RestoreService: BaseSandboxedService, RestoreServiceProtocol, HealthCheckable, Measurable {
    // MARK: - Properties

    private let resticService: ResticServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private let fileManager: FileManagerProtocol
    private let operationQueue: OperationQueue
    private var activeRestores: Set<UUID> = []
    private var _isHealthy: Bool = true

    @objc public var isHealthy: Bool { _isHealthy }

    public func updateHealthStatus() async {
        let noActiveRestores = await activeRestores.isEmpty
        let resticHealthy = await (try? resticService.performHealthCheck()) ?? false
        _isHealthy = noActiveRestores && resticHealthy
    }

    // MARK: - Initialization

    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        resticService: ResticServiceProtocol,
        keychainService: KeychainServiceProtocol,
        fileManager: FileManagerProtocol
    ) {
        self.resticService = resticService
        self.keychainService = keychainService
        self.fileManager = fileManager

        operationQueue = OperationQueue()
        operationQueue.name = "dev.mpy.rBUM.restoreQueue"
        operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - RestoreServiceProtocol Implementation

    public func restore(
        snapshot: ResticSnapshot,
        from repository: Repository,
        paths: [String],
        to target: String
    ) async throws {
        try await measure("Restore Files") {
            // Create operation ID
            let operationId = UUID()

            do {
                // Start operation
                try await startRestoreOperation(
                    operationId,
                    snapshot: snapshot,
                    repository: repository,
                    target: target
                )

                // Validate prerequisites
                try await validateRestorePrerequisites(
                    snapshot: snapshot,
                    repository: repository,
                    target: target
                )

                // Execute restore
                try await resticService.restore(
                    from: URL(fileURLWithPath: repository.path),
                    to: URL(fileURLWithPath: target)
                )

                // Complete operation
                await completeRestoreOperation(operationId, success: true)

                logger.info(
                    "Restore completed",
                    metadata: [
                        "snapshot": .string(snapshot.id),
                        "repository": .string(repository.id.uuidString),
                        "target": .string(target),
                        "paths": .string(paths.joined(separator: ", ")),
                    ],
                    file: #file,
                    function: #function,
                    line: #line
                )

            } catch {
                // Handle failure
                await completeRestoreOperation(operationId, success: false, error: error)
                throw error
            }
        }
    }

    public func listSnapshots(in repository: Repository) async throws -> [ResticSnapshot] {
        try await measure("List Snapshots") {
            let snapshotIds = try await resticService.listSnapshots()
            return snapshotIds.map { id in
                ResticSnapshot(
                    id: id,
                    time: Date(),
                    paths: [],
                    tags: []
                )
            }
        }
    }
}

// MARK: - Restore Errors

public enum RestoreError: LocalizedError {
    case snapshotNotFound
    case snapshotInaccessible
    case targetNotFound
    case targetNotWritable
    case insufficientSpace
    case insufficientPermissions
    case operationNotFound
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .snapshotNotFound:
            "Snapshot not found in repository"
        case .snapshotInaccessible:
            "Snapshot is not accessible"
        case .targetNotFound:
            "Restore target not found"
        case .targetNotWritable:
            "Restore target is not writable"
        case .insufficientSpace:
            "Insufficient space at restore target"
        case .insufficientPermissions:
            "Insufficient permissions for restore target"
        case .operationNotFound:
            "Restore operation not found"
        case let .operationFailed(message):
            "Restore operation failed: \(message)"
        }
    }
}
