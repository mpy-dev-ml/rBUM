import Foundation

/// Type of security operation being performed
@available(macOS 13.0, *)
public enum SecurityOperationType: String {
    case access
    case permission
    case bookmark
    case xpc
}
