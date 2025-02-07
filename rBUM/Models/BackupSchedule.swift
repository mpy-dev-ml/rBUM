//
//  BackupSchedule.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Represents the schedule for a backup operation
public struct BackupSchedule: Codable, Equatable {
    /// The frequency at which the backup should run
    public enum Frequency: String, Codable {
        case hourly
        case daily
        case weekly
        case monthly
        case custom
    }

    /// The frequency of the backup
    public let frequency: Frequency

    /// The time of day to run the backup (for daily, weekly, monthly)
    public let timeOfDay: Date?

    /// The day of week to run the backup (for weekly)
    public let dayOfWeek: Int?

    /// The day of month to run the backup (for monthly)
    public let dayOfMonth: Int?

    /// Custom interval in minutes (for custom frequency)
    public let customIntervalMinutes: Int?

    /// Last successful run time
    public var lastRunTime: Date?

    /// Next scheduled run time
    public var nextRunTime: Date?

    /// Creates a new backup schedule
    /// - Parameters:
    ///   - frequency: The frequency of the backup
    ///   - timeOfDay: The time of day to run the backup (optional)
    ///   - dayOfWeek: The day of week to run the backup (optional)
    ///   - dayOfMonth: The day of month to run the backup (optional)
    ///   - customIntervalMinutes: Custom interval in minutes (optional)
    public init(
        frequency: Frequency,
        timeOfDay: Date? = nil,
        dayOfWeek: Int? = nil,
        dayOfMonth: Int? = nil,
        customIntervalMinutes: Int? = nil,
        lastRunTime: Date? = nil,
        nextRunTime: Date? = nil
    ) {
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
        self.customIntervalMinutes = customIntervalMinutes
        self.lastRunTime = lastRunTime
        self.nextRunTime = nextRunTime
    }

    /// Creates a daily backup schedule at a specific time
    /// - Parameter timeOfDay: The time of day to run the backup
    /// - Returns: A new backup schedule
    public static func daily(at timeOfDay: Date) -> BackupSchedule {
        BackupSchedule(frequency: .daily, timeOfDay: timeOfDay)
    }

    /// Creates a weekly backup schedule
    /// - Parameters:
    ///   - dayOfWeek: The day of week (1-7, where 1 is Monday)
    ///   - timeOfDay: The time of day to run the backup
    /// - Returns: A new backup schedule
    public static func weekly(day dayOfWeek: Int, at timeOfDay: Date) -> BackupSchedule {
        BackupSchedule(frequency: .weekly, timeOfDay: timeOfDay, dayOfWeek: dayOfWeek)
    }

    /// Creates a monthly backup schedule
    /// - Parameters:
    ///   - dayOfMonth: The day of month (1-31)
    ///   - timeOfDay: The time of day to run the backup
    /// - Returns: A new backup schedule
    public static func monthly(day dayOfMonth: Int, at timeOfDay: Date) -> BackupSchedule {
        BackupSchedule(frequency: .monthly, timeOfDay: timeOfDay, dayOfMonth: dayOfMonth)
    }

    /// Creates a custom interval backup schedule
    /// - Parameter minutes: The interval in minutes
    /// - Returns: A new backup schedule
    public static func custom(intervalMinutes: Int) -> BackupSchedule {
        BackupSchedule(frequency: .custom, customIntervalMinutes: intervalMinutes)
    }
}
