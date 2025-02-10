import Foundation

public extension Notification.Name {
    // MARK: - XPC Connection Notifications

    /// Posted when XPC connection is interrupted
    static let xpcConnectionInterrupted = Notification.Name("dev.mpy.rBUM.xpcConnectionInterrupted")

    /// Posted when XPC connection is invalidated
    static let xpcConnectionInvalidated = Notification.Name("dev.mpy.rBUM.xpcConnectionInvalidated")

    /// Posted when XPC connection is restored
    static let xpcConnectionRestored = Notification.Name("dev.mpy.rBUM.xpcConnectionRestored")

    /// Posted when XPC connection state changes
    static let xpcConnectionStateChanged = Notification.Name("dev.mpy.rBUM.xpcConnectionStateChanged")

    /// Posted when XPC service health status changes
    static let xpcHealthStatusChanged = Notification.Name("dev.mpy.rBUM.xpcHealthStatusChanged")

    // MARK: - XPC Command Notifications

    /// Posted when an XPC command completes successfully
    static let xpcCommandCompleted = Notification.Name("dev.mpy.rBUM.xpcCommandCompleted")

    /// Posted when an XPC command fails
    static let xpcCommandFailed = Notification.Name("dev.mpy.rBUM.xpcCommandFailed")

    /// Posted when the XPC queue status changes
    static let xpcQueueStatusChanged = Notification.Name("dev.mpy.rBUM.xpcQueueStatusChanged")
}
