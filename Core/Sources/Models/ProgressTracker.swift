//
//  ProgressTracker.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 8 February 2025
//
import Foundation

/// Protocol for tracking progress of operations
public protocol ProgressTrackerProtocol {
    /// Start tracking an operation
    /// - Parameter operationId: Unique identifier for the operation
    func startOperation(_ operationId: UUID)

    /// Update progress for an operation
    /// - Parameters:
    ///   - operationId: Operation identifier
    ///   - progress: Progress value between 0 and 1
    func updateProgress(_ operationId: UUID, progress: Double)

    /// Mark an operation as failed
    /// - Parameters:
    ///   - operationId: Operation identifier
    ///   - error: Error that caused the failure
    func failOperation(_ operationId: UUID, error: Error)

    /// Reset all progress tracking
    func reset()
}

/// Default implementation of progress tracker
public final class ProgressTracker: ProgressTrackerProtocol {
    // MARK: - Properties

    private let notificationCenter: NotificationCenter
    private var operations: [UUID: OperationState] = [:]
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.ProgressTracker", attributes: .concurrent)

    // MARK: - Initialization

    /// Create a new progress tracker
    /// - Parameter notificationCenter: Center for posting notifications
    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - ProgressTrackerProtocol

    public func startOperation(_ operationId: UUID) {
        queue.async(flags: .barrier) {
            self.operations[operationId] = OperationState(
                startTime: Date(),
                progress: 0,
                status: .running
            )
        }

        notificationCenter.post(
            name: .progressTrackerOperationStarted,
            object: self,
            userInfo: ["operationId": operationId]
        )
    }

    public func updateProgress(_ operationId: UUID, progress: Double) {
        queue.async(flags: .barrier) {
            guard var state = self.operations[operationId] else { return }
            state.progress = progress
            self.operations[operationId] = state
        }

        let userInfo: [String: Any] = [
            "operationId": operationId,
            "progress": progress,
        ]

        notificationCenter.post(
            name: .progressTrackerProgressUpdated,
            object: self,
            userInfo: userInfo
        )
    }

    public func failOperation(_ operationId: UUID, error: Error) {
        queue.async(flags: .barrier) {
            guard var state = self.operations[operationId] else { return }
            state.status = .failed(error)
            self.operations[operationId] = state
        }

        let userInfo: [String: Any] = [
            "operationId": operationId,
            "error": error,
        ]

        notificationCenter.post(
            name: .progressTrackerOperationFailed,
            object: self,
            userInfo: userInfo
        )
    }

    public func reset() {
        queue.async(flags: .barrier) {
            self.operations.removeAll()
        }

        notificationCenter.post(name: .progressTrackerReset, object: self)
    }
}

// MARK: - Supporting Types

private struct OperationState {
    let startTime: Date
    var progress: Double
    var status: OperationStatus
}

private enum OperationStatus {
    case running
    case failed(Error)
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when an operation starts
    static let progressTrackerOperationStarted = Notification.Name("progressTrackerOperationStarted")

    /// Posted when progress is updated
    static let progressTrackerProgressUpdated = Notification.Name("progressTrackerProgressUpdated")

    /// Posted when an operation fails
    static let progressTrackerOperationFailed = Notification.Name("progressTrackerOperationFailed")

    /// Posted when progress is reset
    static let progressTrackerReset = Notification.Name("progressTrackerReset")
}
