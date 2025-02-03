import Foundation

/// Protocol defining notification center operations
protocol NotificationCenterProtocol {
    /// Post a notification
    /// - Parameters:
    ///   - name: Name of the notification
    ///   - object: Optional object to associate with notification
    func post(name: Notification.Name, object: Any?)
}
