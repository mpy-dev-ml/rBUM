import Foundation

/// Protocol for providing date values
/// This allows for better testability by abstracting date creation
public protocol DateProviderProtocol {
    /// Get the current date and time
    func currentDate() -> Date
    
    /// Reset to initial state
    func reset()
}

/// Default implementation of DateProviderProtocol
public final class DateProvider: DateProviderProtocol {
    private var date: Date = Date()
    
    public init() {}
    
    public func currentDate() -> Date {
        return date
    }
    
    public func reset() {
        date = Date()
    }
}
