import Foundation

/// Status of a security operation
@available(macOS 13.0, *)
public enum SecurityOperationStatus: String {
    case success
    case failure
    case pending
}
