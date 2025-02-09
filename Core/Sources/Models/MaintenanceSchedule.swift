import Foundation

/// Configuration for repository maintenance scheduling
public struct MaintenanceSchedule: Codable, Equatable {
    /// Days of the week to run maintenance
    public let days: Set<MaintenanceDay>
    
    /// Hour of the day to start maintenance (0-23)
    public let hour: Int
    
    /// Minute of the hour to start maintenance (0-59)
    public let minute: Int
    
    /// Whether maintenance should run automatically
    public let isEnabled: Bool
    
    /// Maximum duration in minutes before maintenance is considered stuck
    public let maxDuration: Int
    
    /// Tasks to perform during maintenance
    public let tasks: Set<MaintenanceTask>
    
    public init(
        days: Set<MaintenanceDay> = [.sunday],
        hour: Int = 2, // 2 AM default
        minute: Int = 0,
        isEnabled: Bool = true,
        maxDuration: Int = 120,
        tasks: Set<MaintenanceTask> = MaintenanceTask.allCases
    ) {
        self.days = days
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
        self.isEnabled = isEnabled
        self.maxDuration = max(maxDuration, 30)
        self.tasks = tasks
    }
}

/// Days of the week for maintenance scheduling
public enum MaintenanceDay: String, Codable, CaseIterable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    
    /// Convert from Calendar.Component.weekday
    public static func from(weekday: Int) -> MaintenanceDay? {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
    
    /// Convert to Calendar.Component.weekday
    public var weekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

/// Tasks that can be performed during maintenance
public enum MaintenanceTask: String, Codable, CaseIterable {
    case healthCheck = "health_check"
    case prune = "prune"
    case rebuildIndex = "rebuild_index"
    case checkIntegrity = "check_integrity"
    case removeStaleSnapshots = "remove_stale_snapshots"
}

/// Result of a maintenance run
public struct MaintenanceResult: Codable, Equatable {
    /// When the maintenance run started
    public let startTime: Date
    
    /// When the maintenance run completed
    public let endTime: Date
    
    /// Tasks that were completed successfully
    public let completedTasks: Set<MaintenanceTask>
    
    /// Tasks that failed
    public let failedTasks: [MaintenanceTask: Error]
    
    /// Whether the maintenance run was successful overall
    public var isSuccessful: Bool {
        failedTasks.isEmpty
    }
    
    /// Duration of the maintenance run in seconds
    public var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
