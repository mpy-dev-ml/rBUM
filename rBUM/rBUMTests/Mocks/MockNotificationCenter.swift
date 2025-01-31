import Foundation
@testable import rBUM

/// Mock implementation of NotificationCenter for testing
final class MockNotificationCenter: NotificationCenterProtocol {
    private var notifications: [(name: Notification.Name, object: Any?)] = []
    private var error: Error?
    
    /// Reset mock to initial state
    func reset() {
        notifications = []
        error = nil
    }
    
    /// Set an error to be thrown by operations
    func setError(_ error: Error) {
        self.error = error
    }
    
    /// Get posted notifications
    var postedNotifications: [(name: Notification.Name, object: Any?)] {
        notifications
    }
    
    // MARK: - Protocol Implementation
    
    func post(name: Notification.Name, object: Any?) {
        notifications.append((name: name, object: object))
    }
}
