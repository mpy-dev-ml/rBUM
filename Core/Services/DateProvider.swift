import Foundation

/// Protocol for providing dates, allowing for testing and dependency injection
public protocol DateProviderProtocol {
    /// Get the current date
    var now: Date { get }
}

/// Default implementation of DateProviderProtocol
public final class DateProvider: DateProviderProtocol {
    public init() {}
    
    /// Get the current date
    public var now: Date {
        Date()
    }
}
