//
//  BackupQueue.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Core
import Foundation

/// Priority level for backup jobs
public enum BackupJobPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    
    public static func < (lhs: BackupJobPriority, rhs: BackupJobPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A backup job that can be queued for execution
public struct BackupJob: Identifiable, Equatable {
    /// Unique identifier for the job
    public let id: UUID
    
    /// Priority level of the job
    public let priority: BackupJobPriority
    
    /// Create a new backup job
    /// - Parameters:
    ///   - id: Unique identifier for the job
    ///   - priority: Priority level of the job
    public init(id: UUID, priority: BackupJobPriority) {
        self.id = id
        self.priority = priority
    }
}

/// Queue for managing and executing backup jobs
public final class BackupQueue {
    // MARK: - Properties
    
    private let dateProvider: any DateProviderProtocol
    private let notificationCenter: NotificationCenter
    private let progressTracker: any ProgressTrackerProtocol
    private var jobs: [BackupJob] = []
    private var runningJobs: Set<UUID> = []
    private var jobProgress: [UUID: Double] = [:]
    private var isProcessing: Bool = false
    
    /// Maximum number of jobs that can run concurrently
    public let maxConcurrentJobs: Int
    
    /// Whether the queue is empty
    public var isEmpty: Bool { jobs.isEmpty }
    
    /// Number of jobs in the queue
    public var count: Int { jobs.count }
    
    /// Whether the queue is currently processing jobs
    public var isProcessingJobs: Bool { isProcessing }
    
    /// Currently processing jobs
    public var processingJobs: Set<UUID> { runningJobs }
    
    /// Overall progress of all jobs (0 to 1)
    public var overallProgress: Double {
        guard !jobProgress.isEmpty else { return 0 }
        return jobProgress.values.reduce(0, +) / Double(jobProgress.count)
    }
    
    // MARK: - Initialization
    
    /// Create a new backup queue
    /// - Parameters:
    ///   - dateProvider: Provider for current date and time
    ///   - notificationCenter: Center for posting notifications
    ///   - progressTracker: Tracker for job progress
    ///   - maxConcurrentJobs: Maximum number of concurrent jobs
    public init(
        dateProvider: any DateProviderProtocol,
        notificationCenter: NotificationCenter,
        progressTracker: any ProgressTrackerProtocol,
        maxConcurrentJobs: Int = 3
    ) {
        self.dateProvider = dateProvider
        self.notificationCenter = notificationCenter
        self.progressTracker = progressTracker
        self.maxConcurrentJobs = maxConcurrentJobs
    }
    
    // MARK: - Queue Operations
    
    /// Add a job to the queue
    /// - Parameter job: Job to add
    /// - Throws: Error if job is already in queue
    public func enqueue(_ job: BackupJob) throws {
        guard !jobs.contains(job) else {
            throw BackupQueueError.duplicateJob(job.id)
        }
        
        jobs.append(job)
        jobs.sort { $0.priority > $1.priority }
        jobProgress[job.id] = 0
        
        notificationCenter.post(name: .backupQueueJobAdded, object: job)
    }
    
    /// Remove a job from the queue
    /// - Parameter job: Job to remove
    /// - Throws: Error if job is not in queue or is running
    public func dequeue(_ job: BackupJob) throws {
        guard let index = jobs.firstIndex(of: job) else {
            throw BackupQueueError.jobNotFound(job.id)
        }
        
        guard !runningJobs.contains(job.id) else {
            throw BackupQueueError.jobRunning(job.id)
        }
        
        jobs.remove(at: index)
        jobProgress.removeValue(forKey: job.id)
        notificationCenter.post(name: .backupQueueJobRemoved, object: job)
    }
    
    /// Get the next job in the queue without removing it
    /// - Returns: The next job, or nil if queue is empty
    public func peek() -> BackupJob? {
        jobs.first
    }
    
    /// Find a job by its ID
    /// - Parameter id: Job ID to find
    /// - Returns: The job if found, nil otherwise
    public func findJob(withId id: UUID) -> BackupJob? {
        jobs.first { $0.id == id }
    }
    
    /// Start processing jobs in the queue
    public func startProcessing() {
        isProcessing = true
        processNextJobs()
    }
    
    /// Stop processing jobs in the queue
    public func stopProcessing() {
        isProcessing = false
        notificationCenter.post(name: .backupQueueStopped, object: nil)
    }
    
    /// Update progress for a job
    /// - Parameters:
    ///   - jobId: ID of the job to update
    ///   - progress: New progress value (0 to 1)
    ///   - message: Optional progress message
    public func updateProgress(forJob jobId: UUID, progress: Double, message: String? = nil) {
        jobProgress[jobId] = progress
        
        if let message = message {
            progressTracker.update(progress: progress, message: message)
        }
        
        notificationCenter.post(
            name: .backupQueueJobProgressUpdated,
            object: nil,
            userInfo: [
                "jobId": jobId,
                "progress": progress
            ]
        )
    }
    
    /// Handle an error for a job
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - jobId: ID of the job that failed
    public func handleError(_ error: Error, forJob jobId: UUID) {
        runningJobs.remove(jobId)
        jobProgress.removeValue(forKey: jobId)
        
        notificationCenter.post(
            name: .backupQueueJobFailed,
            object: nil,
            userInfo: [
                "jobId": jobId,
                "error": error
            ]
        )
    }
    
    /// Complete a job
    /// - Parameter jobId: ID of the job to complete
    public func completeJob(_ jobId: UUID) {
        runningJobs.remove(jobId)
        jobProgress.removeValue(forKey: jobId)
        
        if let job = findJob(withId: jobId) {
            if let index = jobs.firstIndex(of: job) {
                jobs.remove(at: index)
            }
            notificationCenter.post(name: .backupQueueJobCompleted, object: job)
        }
        
        processNextJobs()
    }
    
    /// Save queue state
    public func save() throws {
        // TODO: Implement persistence
    }
    
    /// Load queue state
    public func load() throws {
        // TODO: Implement persistence
    }
    
    // MARK: - Private Methods
    
    private func processNextJobs() {
        guard isProcessing && !jobs.isEmpty else { return }
        
        let availableSlots = maxConcurrentJobs - runningJobs.count
        guard availableSlots > 0 else { return }
        
        for job in jobs.prefix(availableSlots) where !runningJobs.contains(job.id) {
            runningJobs.insert(job.id)
            notificationCenter.post(name: .backupQueueJobStarted, object: job)
            
            // Simulate job progress
            updateProgress(forJob: job.id, progress: 0.0, message: "Starting job \(job.id)")
            
            // TODO: Implement actual job execution
            updateProgress(forJob: job.id, progress: 1.0, message: "Completed job \(job.id)")
            completeJob(job.id)
        }
    }
}

// MARK: - Errors

/// Errors that can occur during backup queue operations
public enum BackupQueueError: LocalizedError {
    /// Job with the given ID is already in the queue
    case duplicateJob(UUID)
    
    /// Job with the given ID was not found in the queue
    case jobNotFound(UUID)
    
    /// Job with the given ID is currently running
    case jobRunning(UUID)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateJob(let id):
            return "Job \(id) is already in the queue"
        case .jobNotFound(let id):
            return "Job \(id) was not found in the queue"
        case .jobRunning(let id):
            return "Job \(id) is currently running"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when a job is added to the queue
    static let backupQueueJobAdded = Notification.Name("backupQueueJobAdded")
    
    /// Posted when a job is removed from the queue
    static let backupQueueJobRemoved = Notification.Name("backupQueueJobRemoved")
    
    /// Posted when a job starts executing
    static let backupQueueJobStarted = Notification.Name("backupQueueJobStarted")
    
    /// Posted when a job's progress is updated
    static let backupQueueJobProgressUpdated = Notification.Name("backupQueueJobProgressUpdated")
    
    /// Posted when a job fails
    static let backupQueueJobFailed = Notification.Name("backupQueueJobFailed")
    
    /// Posted when a job completes execution
    static let backupQueueJobCompleted = Notification.Name("backupQueueJobCompleted")
    
    /// Posted when the queue stops processing jobs
    static let backupQueueStopped = Notification.Name("backupQueueStopped")
}
