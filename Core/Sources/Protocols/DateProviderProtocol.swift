//
//  DateProviderProtocol.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation

/// Protocol for providing dates, allowing for easier testing of time-dependent code.
///
/// The `DateProviderProtocol` abstracts the source of date/time information,
/// enabling:
/// - Deterministic testing of time-dependent code
/// - Mocking of dates for specific test scenarios
/// - Consistent time handling across the application
///
/// Example usage:
/// ```swift
/// class BackupScheduler {
///     private let dateProvider: DateProviderProtocol
///
///     init(dateProvider: DateProviderProtocol) {
///         self.dateProvider = dateProvider
///     }
///
///     func shouldRunBackup() -> Bool {
///         let lastBackup = getLastBackupDate()
///         let now = dateProvider.now()
///         return now.timeIntervalSince(lastBackup) >= 24 * 3600
///     }
/// }
/// ```
public protocol DateProviderProtocol {
    /// Get the current date and time
    /// - Returns: The current `Date`, or a mocked date in test scenarios
    /// - Note: Implementations should be thread-safe and handle time zones appropriately
    func now() -> Date
}

/// Default implementation of DateProviderProtocol using system time
public struct DateProvider: DateProviderProtocol {
    /// Initialize a new DateProvider
    /// - Note: This provider uses the system clock and respects the system time zone
    public init() {}

    /// Get the current system date and time
    /// - Returns: The current system `Date`
    public func now() -> Date {
        Date()
    }
}
