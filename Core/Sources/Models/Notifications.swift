import Foundation

extension Notification.Name {
    // MARK: - XPC Connection Notifications
    
    /// Posted when XPC connection is interrupted
    public static let xpcConnectionInterrupted = Notification.Name("dev.mpy.rBUM.xpcConnectionInterrupted")
    
    /// Posted when XPC connection is invalidated
    public static let xpcConnectionInvalidated = Notification.Name("dev.mpy.rBUM.xpcConnectionInvalidated")
    
    /// Posted when XPC connection is restored
    public static let xpcConnectionRestored = Notification.Name("dev.mpy.rBUM.xpcConnectionRestored")
    
    /// Posted when XPC connection state changes
    public static let xpcConnectionStateChanged = Notification.Name("dev.mpy.rBUM.xpcConnectionStateChanged")
    
    /// Posted when XPC service health status changes
    public static let xpcHealthStatusChanged = Notification.Name("dev.mpy.rBUM.xpcHealthStatusChanged")
    
    // MARK: - XPC Command Notifications
    
    /// Posted when an XPC command completes successfully
    public static let xpcCommandCompleted = Notification.Name("dev.mpy.rBUM.xpcCommandCompleted")
    
    /// Posted when an XPC command fails
    public static let xpcCommandFailed = Notification.Name("dev.mpy.rBUM.xpcCommandFailed")
    
    /// Posted when the XPC queue status changes
    public static let xpcQueueStatusChanged = Notification.Name("dev.mpy.rBUM.xpcQueueStatusChanged")
}
