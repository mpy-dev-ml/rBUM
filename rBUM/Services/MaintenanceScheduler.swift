import Core
import Foundation

/// Service for scheduling and managing automatic repository maintenance
final class MaintenanceScheduler {
    private let backupService: BackupService
    private let logger: LoggerProtocol
    private let notificationCenter: NotificationCenter
    private let taskScheduler: MaintenanceTaskScheduler
    private let configStore: MaintenanceConfigurationStore
    private let taskRecovery: MaintenanceTaskRecovery
    private var timer: Timer?
    private var runningMaintenance: Set<String> = []
    private let queue = DispatchQueue(label: "com.rbum.maintenance")
    
    private var schedules: [String: MaintenanceSchedule] = [:] // Repository path -> Schedule
    private var lastRuns: [String: Date] = [:] // Repository path -> Last run time
    
    init(
        backupService: BackupService,
        logger: LoggerProtocol,
        notificationCenter: NotificationCenter = .default,
        taskScheduler: MaintenanceTaskScheduler? = nil
    ) throws {
        self.backupService = backupService
        self.logger = logger
        self.notificationCenter = notificationCenter
        
        // Initialize configuration store
        let store = try MaintenanceConfigurationStore(logger: logger)
        self.configStore = store
        
        // Initialize task recovery
        self.taskRecovery = MaintenanceTaskRecovery(
            logger: logger,
            configStore: store
        )
        
        // Initialize task scheduler with persisted configurations
        let configurations = try store.loadTaskConfigurations()
        self.taskScheduler = taskScheduler ?? MaintenanceTaskScheduler(
            logger: logger,
            taskConfigurations: configurations
        )
        
        // Load persisted schedules
        self.schedules = try store.loadSchedules()
        
        // Start checking schedule every minute
        startScheduleTimer()
    }
    
    deinit {
        stopScheduleTimer()
    }
    
    // MARK: - Public Methods
    
    /// Sets the maintenance schedule for a repository
    func setSchedule(_ schedule: MaintenanceSchedule, for repository: Repository) {
        queue.async {
            self.schedules[repository.path] = schedule
            try? self.configStore.saveSchedules(self.schedules)
            self.logger.info("Updated schedule for repository: \(repository.path)")
        }
    }
    
    /// Gets the maintenance schedule for a repository
    func getSchedule(for repository: Repository) -> MaintenanceSchedule? {
        queue.sync {
            return schedules[repository.path]
        }
    }
    
    /// Gets the last maintenance run time for a repository
    func getLastRunTime(for repository: Repository) -> Date? {
        queue.sync {
            return lastRuns[repository.path]
        }
    }
    
    /// Triggers maintenance immediately for a repository
    func triggerMaintenance(for repository: Repository) async throws -> MaintenanceResult {
        guard let schedule = getSchedule(for: repository) else {
            throw MaintenanceError.noScheduleFound
        }
        
        return try await performMaintenance(for: repository, schedule: schedule)
    }
    
    // MARK: - Private Methods
    
    private func startScheduleTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            self?.checkSchedules()
        }
    }
    
    private func stopScheduleTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkSchedules() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let now = Date()
            let calendar = Calendar.current
            
            for (path, schedule) in self.schedules {
                guard schedule.isEnabled else { continue }
                
                // Check if maintenance should run now
                if self.shouldRunMaintenance(schedule: schedule, lastRun: self.lastRuns[path], now: now) {
                    guard !self.runningMaintenance.contains(path) else {
                        self.logger.warning("Maintenance already running for: \(path)")
                        continue
                    }
                    
                    // Create repository instance
                    let repository = Repository(path: path, settings: .init(), options: nil, credentials: nil)
                    
                    // Start maintenance
                    self.runningMaintenance.insert(path)
                    
                    Task {
                        do {
                            let result = try await self.performMaintenance(
                                for: repository,
                                schedule: schedule
                            )
                            
                            self.queue.async {
                                self.lastRuns[path] = now
                                self.runningMaintenance.remove(path)
                                
                                // Post notification with result
                                self.notificationCenter.post(
                                    name: .maintenanceCompleted,
                                    object: nil,
                                    userInfo: [
                                        "repository": repository,
                                        "result": result
                                    ]
                                )
                            }
                        } catch {
                            self.logger.error("Maintenance failed: \(error.localizedDescription)")
                            self.queue.async {
                                self.runningMaintenance.remove(path)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func shouldRunMaintenance(
        schedule: MaintenanceSchedule,
        lastRun: Date?,
        now: Date
    ) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: now)
        
        guard let weekday = components.weekday,
              let currentDay = MaintenanceDay.from(weekday: weekday),
              let hour = components.hour,
              let minute = components.minute else {
            return false
        }
        
        // Check if today is a scheduled day
        guard schedule.days.contains(currentDay) else {
            return false
        }
        
        // Check if it's time to run
        guard hour == schedule.hour && minute == schedule.minute else {
            return false
        }
        
        // Check if it hasn't run today
        if let lastRun = lastRun {
            return !calendar.isDate(lastRun, inSameDayAs: now)
        }
        
        return true
    }
    
    private func performMaintenance(
        for repository: Repository,
        schedule: MaintenanceSchedule
    ) async throws -> MaintenanceResult {
        let startTime = Date()
        var completedTasks: Set<MaintenanceTask> = []
        var failedTasks: [MaintenanceTask: Error] = [:]
        
        // Get task groups based on priority and resources
        let taskGroups = taskScheduler.scheduleTasks(schedule.tasks)
        
        for group in taskGroups where await executeTaskGroup(
            group,
            repository: repository,
            startTime: startTime,
            schedule: schedule,
            completedTasks: &completedTasks,
            failedTasks: &failedTasks
        ) {
            continue
        }
        
        return MaintenanceResult(
            startTime: startTime,
            endTime: Date(),
            completedTasks: completedTasks,
            failedTasks: failedTasks
        )
    }
    
    private func executeTaskGroup(
        _ group: MaintenanceTaskGroup,
        repository: Repository,
        startTime: Date,
        schedule: MaintenanceSchedule,
        completedTasks: inout Set<MaintenanceTask>,
        failedTasks: inout [MaintenanceTask: Error]
    ) async -> Bool {
        // Check if we can run this group
        guard taskScheduler.canRunTaskGroup(group) else {
            logger.warning("Insufficient resources for task group: \(group.tasks)")
            return true
        }
        
        // Set up timeout for the group
        let estimatedDuration = taskScheduler.estimateGroupDuration(group)
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(estimatedDuration * 1.5 * 1_000_000_000))
            throw MaintenanceError.timeout
        }
        
        // Execute tasks in the group
        let groupTask = Task {
            try await withThrowingTaskGroup(of: MaintenanceTask.self) { group in
                for task in group.tasks {
                    group.addTask {
                        try await self.executeMaintenanceTask(task, for: repository)
                        return task
                    }
                }
                
                // Collect results
                for try await completedTask in group {
                    completedTasks.insert(completedTask)
                }
            }
        }
        
        do {
            try await withTaskGroup(of: Void.self) { group in
                group.addTask { try await groupTask.value }
                group.addTask { try await timeoutTask.value }
            }
        } catch {
            if error is MaintenanceError {
                logger.error("Task group timed out: \(group.tasks)")
                for task in group.tasks {
                    failedTasks[task] = error
                }
            }
        }
        
        timeoutTask.cancel()
        
        // Check if we've exceeded total maintenance window
        if Date().timeIntervalSince(startTime) > Double(schedule.maxDuration * 60) {
            logger.warning("Maintenance window exceeded")
            return false
        }
        
        return true
    }
    
    private func executeMaintenanceTask(
        _ task: MaintenanceTask,
        for repository: Repository
    ) async throws {
        try await taskRecovery.executeWithRetry(
            task: task,
            repository: repository
        ) {
            switch task {
            case .healthCheck:
                _ = try await self.backupService.checkHealth(for: repository)
            case .prune:
                try await self.backupService.pruneRepository(repository)
            case .rebuildIndex:
                try await self.backupService.rebuildIndex(repository)
            case .checkIntegrity:
                try await self.backupService.checkIntegrity(repository)
            case .removeStaleSnapshots:
                try await self.backupService.removeStaleSnapshots(repository)
            }
        }
    }
}

// MARK: - Errors

enum MaintenanceError: Error {
    case noScheduleFound
    case timeout
    case taskFailed(MaintenanceTask, Error)
}

// MARK: - Notifications

extension Notification.Name {
    static let maintenanceCompleted = Notification.Name("MaintenanceCompleted")
}
