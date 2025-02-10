import Foundation

/// Priority levels for maintenance tasks
public enum TaskPriority: Int, Comparable {
    case critical = 0 // Must run, blocks other tasks
    case high = 1 // Should run soon
    case medium = 2 // Run when convenient
    case low = 3 // Run if resources available

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Configuration for a maintenance task
public struct TaskConfiguration: Codable, Equatable {
    /// The maintenance task
    public let task: MaintenanceTask

    /// Task priority
    public let priority: TaskPriority

    /// Estimated duration in minutes
    public let estimatedDuration: Int

    /// Maximum memory usage in MB
    public let maxMemoryUsage: Int

    /// CPU intensity (0-100)
    public let cpuIntensity: Int

    /// Whether the task can run in parallel with others
    public let allowsParallel: Bool

    /// Tasks that must complete before this one
    public let dependencies: Set<MaintenanceTask>

    /// Whether the task can be interrupted
    public let isInterruptible: Bool

    /// Initializes a new task configuration
    /// - Parameters:
    ///   - task: The maintenance task
    ///   - priority: Task priority
    ///   - estimatedDuration: Estimated duration in minutes
    ///   - maxMemoryUsage: Maximum memory usage in MB
    ///   - cpuIntensity: CPU intensity (0-100)
    ///   - allowsParallel: Whether the task can run in parallel with others
    ///   - dependencies: Tasks that must complete before this one
    ///   - isInterruptible: Whether the task can be interrupted
    public init(
        task: MaintenanceTask,
        priority: TaskPriority,
        estimatedDuration: Int,
        maxMemoryUsage: Int,
        cpuIntensity: Int,
        allowsParallel: Bool = false,
        dependencies: Set<MaintenanceTask> = [],
        isInterruptible: Bool = false
    ) {
        self.task = task
        self.priority = priority
        self.estimatedDuration = max(estimatedDuration, 1)
        self.maxMemoryUsage = max(maxMemoryUsage, 50)
        self.cpuIntensity = min(max(cpuIntensity, 0), 100)
        self.allowsParallel = allowsParallel
        self.dependencies = dependencies
        self.isInterruptible = isInterruptible
    }
}

/// Default configurations for maintenance tasks
public extension TaskConfiguration {
    /// Default task configurations for each maintenance task type
    static let defaults: [MaintenanceTask: TaskConfiguration] = [
        .healthCheck: TaskConfiguration(
            task: .healthCheck,
            priority: .critical,
            estimatedDuration: 5,
            maxMemoryUsage: 100,
            cpuIntensity: 30,
            allowsParallel: true,
            isInterruptible: true
        ),
        .checkIntegrity: TaskConfiguration(
            task: .checkIntegrity,
            priority: .high,
            estimatedDuration: 30,
            maxMemoryUsage: 200,
            cpuIntensity: 70,
            dependencies: [.healthCheck]
        ),
        .prune: TaskConfiguration(
            task: .prune,
            priority: .medium,
            estimatedDuration: 20,
            maxMemoryUsage: 150,
            cpuIntensity: 50,
            dependencies: [.healthCheck]
        ),
        .rebuildIndex: TaskConfiguration(
            task: .rebuildIndex,
            priority: .high,
            estimatedDuration: 15,
            maxMemoryUsage: 300,
            cpuIntensity: 80,
            dependencies: [.healthCheck]
        ),
        .removeStaleSnapshots: TaskConfiguration(
            task: .removeStaleSnapshots,
            priority: .low,
            estimatedDuration: 10,
            maxMemoryUsage: 100,
            cpuIntensity: 40,
            allowsParallel: true,
            isInterruptible: true,
            dependencies: [.healthCheck]
        ),
    ]
}
