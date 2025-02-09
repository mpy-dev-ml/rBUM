@testable import Core
import Foundation

final class MockLogger: LoggerProtocol {
    // MARK: - Properties
    
    /// Represents a logged message
    struct LogEntry {
        let level: String
        let message: String
        let privacy: PrivacyLevel
    }
    
    private(set) var messages: [LogEntry] = []
    
    // MARK: - LoggerProtocol Implementation
    
    func debug(_ message: String, privacy: PrivacyLevel) {
        messages.append(LogEntry(level: "debug", message: message, privacy: privacy))
    }
    
    func info(_ message: String, privacy: PrivacyLevel) {
        messages.append(LogEntry(level: "info", message: message, privacy: privacy))
    }
    
    func warning(_ message: String, privacy: PrivacyLevel) {
        messages.append(LogEntry(level: "warning", message: message, privacy: privacy))
    }
    
    func error(_ message: String, privacy: PrivacyLevel) {
        messages.append(LogEntry(level: "error", message: message, privacy: privacy))
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        messages.removeAll()
    }
    
    func containsMessage(_ message: String, level: String? = nil) -> Bool {
        messages.contains { log in
            if let level = level {
                return log.level == level && log.message.contains(message)
            }
            return log.message.contains(message)
        }
    }
    
    func messageCount(level: String? = nil) -> Int {
        if let level = level {
            return messages.filter { $0.level == level }.count
        }
        return messages.count
    }
}
