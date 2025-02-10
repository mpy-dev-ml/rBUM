import Core
import Foundation

/// Schedules and manages maintenance task execution based on priorities and system resources
final class MaintenanceTaskScheduler {
    private let logger: LoggerProtocol
    private let processInfo: ProcessInfo
    private let taskConfigurations: [MaintenanceTask: TaskConfiguration]

    /// Maximum CPU usage percentage allowed (0-100)
    private let maxCPUUsage: Int

    /// Maximum memory usage in MB
    private let maxMemoryUsage: Int

    init(
        logger: LoggerProtocol,
        processInfo: ProcessInfo = .processInfo,
        taskConfigurations: [MaintenanceTask: TaskConfiguration]? = nil,
        maxCPUUsage: Int = 70,
        maxMemoryUsage: Int = 500
    ) {
        self.logger = logger
        self.processInfo = processInfo
        self.taskConfigurations = taskConfigurations ?? TaskConfiguration.defaults
        self.maxCPUUsage = min(max(maxCPUUsage, 30), 90)
        self.maxMemoryUsage = max(maxMemoryUsage, 200)
    }

    /// Schedules tasks based on priority, dependencies, and system resources
    func scheduleTasks(_ tasks: Set<MaintenanceTask>) -> [MaintenanceTaskGroup] {
        let configs = tasks.compactMap { taskConfigurations[$0] }
            .sorted { $0.priority < $1.priority }

        var taskGroups: [MaintenanceTaskGroup] = []
        var completedTasks: Set<MaintenanceTask> = []
        var currentGroup = MaintenanceTaskGroup()
        var currentCPU = 0
        var currentMemory = 0

        for config in configs {
            // Skip if dependencies aren't met
            guard completedTasks.isSuperset(of: config.dependencies) else {
                continue
            }

            // Check if task can be added to current group
            let canAddToGroup = currentGroup.tasks.allSatisfy { existingTask in
                let existingConfig = taskConfigurations[existingTask]!
                return existingConfig.allowsParallel && config.allowsParallel
            }

            // Check resource constraints
            let wouldExceedCPU = currentCPU + config.cpuIntensity > maxCPUUsage
            let wouldExceedMemory = currentMemory + config.maxMemoryUsage > maxMemoryUsage

            if !canAddToGroup || wouldExceedCPU || wouldExceedMemory {
                if !currentGroup.tasks.isEmpty {
                    taskGroups.append(currentGroup)
                    completedTasks.formUnion(currentGroup.tasks)
                }
                currentGroup = MaintenanceTaskGroup()
                currentCPU = 0
                currentMemory = 0
            }

            currentGroup.tasks.insert(config.task)
            currentCPU += config.cpuIntensity
            currentMemory += config.maxMemoryUsage

            // Add critical tasks to their own group
            if config.priority == .critical {
                taskGroups.append(currentGroup)
                completedTasks.formUnion(currentGroup.tasks)
                currentGroup = MaintenanceTaskGroup()
                currentCPU = 0
                currentMemory = 0
            }
        }

        // Add remaining tasks
        if !currentGroup.tasks.isEmpty {
            taskGroups.append(currentGroup)
        }

        return taskGroups
    }

    /// Estimates the duration for a group of tasks
    func estimateGroupDuration(_ group: MaintenanceTaskGroup) -> TimeInterval {
        let configs = group.tasks.compactMap { taskConfigurations[$0] }

        if configs.count == 1 {
            return TimeInterval(configs[0].estimatedDuration * 60)
        }

        // For parallel tasks, use the longest duration
        // For sequential tasks, sum the durations
        let totalDuration = configs.reduce(0) { result, config in
            if config.allowsParallel {
                max(result, config.estimatedDuration)
            } else {
                result + config.estimatedDuration
            }
        }

        return TimeInterval(totalDuration * 60)
    }

    /// Checks if the system has enough resources to run a task group
    func canRunTaskGroup(_ group: MaintenanceTaskGroup) -> Bool {
        let configs = group.tasks.compactMap { taskConfigurations[$0] }

        let totalCPU = configs.reduce(0) { $0 + $1.cpuIntensity }
        let totalMemory = configs.reduce(0) { $0 + $1.maxMemoryUsage }

        // Check system resources
        let availableMemory = processInfo.physicalMemory / 1024 / 1024 // Convert to MB
        let systemLoad = processInfo.systemUptime // Use as a rough CPU indicator

        return totalCPU <= maxCPUUsage &&
            totalMemory <= min(maxMemoryUsage, Int(availableMemory) / 2) &&
            systemLoad < 5 // System not under heavy load
    }
}

/// Group of maintenance tasks that can be executed together
struct MaintenanceTaskGroup: Equatable {
    var tasks: Set<MaintenanceTask>

    init(tasks: Set<MaintenanceTask> = []) {
        self.tasks = tasks
    }
}
