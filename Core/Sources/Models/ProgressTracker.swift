//
//  ProgressTracker.swift
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

import Foundation

/// Protocol for tracking progress of operations
public protocol ProgressTrackerProtocol {
    /// Update the progress and message
    /// - Parameters:
    ///   - progress: Progress value between 0 and 1
    ///   - message: Message describing the current state
    func update(progress: Double, message: String)

    /// Reset the progress tracker to initial state
    func reset()
}

/// Default implementation of progress tracker
public final class ProgressTracker: ProgressTrackerProtocol {
    // MARK: - Properties

    private let notificationCenter: NotificationCenter
    private var currentProgress: Double = 0
    private var currentMessage: String = ""

    // MARK: - Initialization

    /// Create a new progress tracker
    /// - Parameter notificationCenter: Center for posting notifications
    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - ProgressTrackerProtocol

    public func update(progress: Double, message: String) {
        currentProgress = progress
        currentMessage = message

        let userInfo: [String: Any] = [
            "progress": progress,
            "message": message,
        ]

        notificationCenter.post(
            name: .progressTrackerUpdated,
            object: self,
            userInfo: userInfo
        )
    }

    public func reset() {
        currentProgress = 0
        currentMessage = ""

        notificationCenter.post(name: .progressTrackerReset, object: self)
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// Posted when progress is updated
    static let progressTrackerUpdated = Notification.Name("progressTrackerUpdated")

    /// Posted when progress is reset
    static let progressTrackerReset = Notification.Name("progressTrackerReset")
}
