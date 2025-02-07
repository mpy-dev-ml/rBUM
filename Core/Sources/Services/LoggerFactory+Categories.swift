import Foundation

extension LoggerFactory {
    // MARK: - Logger Categories
    
    /// Categories for different logging domains
    public enum Category: String {
        // System
        case system = "System"
        case health = "Health"
        case performance = "Performance"
        
        // Security
        case security = "Security"
        case permissions = "Permissions"
        case keychain = "Keychain"
        
        // Backup
        case backup = "Backup"
        case restore = "Restore"
        case restic = "Restic"
        
        // Resources
        case bookmarks = "Bookmarks"
        case files = "Files"
        case directories = "Directories"
        
        // Communication
        case xpc = "XPC"
        case network = "Network"
        case ipc = "IPC"
        
        // Development
        case debug = "Debug"
        case testing = "Testing"
        case analytics = "Analytics"
    }
    
    /// Create a new logger for the given category
    /// - Parameter category: Category enum value
    /// - Returns: A new logger instance conforming to LoggerProtocol
    public static func createLogger(category: Category) -> LoggerProtocol {
        createLogger(category: category.rawValue)
    }
}
