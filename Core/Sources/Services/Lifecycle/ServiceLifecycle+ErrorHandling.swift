import Foundation

/// Extension providing error handling capabilities for lifecycle managed services
public extension LifecycleManaged where Self: LoggingService {
    /// Handle an error by transitioning to the error state and logging
    /// - Parameters:
    ///   - error: Error to handle
    ///   - operation: Operation that caused the error
    ///   - file: Source file where error occurred
    ///   - function: Function where error occurred
    ///   - line: Line number where error occurred
    /// - Returns: Error for propagation
    func handleError(
        _ error: Error,
        during operation: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> Error {
        logger.error(
            "Error during \(operation): \(error.localizedDescription)",
            file: file,
            function: function,
            line: line
        )

        // Log additional context if available
        if let serviceError = error as? ServiceError {
            logger.error(
                "Service error details: \(String(describing: serviceError))",
                file: file,
                function: function,
                line: line
            )
        }

        return error
    }

    /// Handle an error by transitioning to the error state and logging, then rethrowing
    /// - Parameters:
    ///   - error: Error to handle
    ///   - operation: Operation that caused the error
    ///   - file: Source file where error occurred
    ///   - function: Function where error occurred
    ///   - line: Line number where error occurred
    /// - Throws: The handled error
    func handleAndRethrow(
        _ error: Error,
        during operation: String,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) throws {
        throw handleError(
            error,
            during: operation,
            file: file,
            function: function,
            line: line
        )
    }

    /// Handle an error by transitioning to the error state and logging, then returning a default value
    /// - Parameters:
    ///   - error: Error to handle
    ///   - operation: Operation that caused the error
    ///   - defaultValue: Default value to return
    ///   - file: Source file where error occurred
    ///   - function: Function where error occurred
    ///   - line: Line number where error occurred
    /// - Returns: The default value
    func handleWithDefault<T>(
        _ error: Error,
        during operation: String,
        defaultValue: T,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) -> T {
        _ = handleError(
            error,
            during: operation,
            file: file,
            function: function,
            line: line
        )
        return defaultValue
    }

    /// Handle an error by transitioning to the error state and logging, then executing a recovery block
    /// - Parameters:
    ///   - error: Error to handle
    ///   - operation: Operation that caused the error
    ///   - recovery: Recovery block to execute
    ///   - file: Source file where error occurred
    ///   - function: Function where error occurred
    ///   - line: Line number where error occurred
    /// - Returns: Result of recovery block
    func handleWithRecovery<T>(
        _ error: Error,
        during operation: String,
        recovery: () throws -> T,
        file: StaticString = #file,
        function: StaticString = #function,
        line: UInt = #line
    ) rethrows -> T {
        _ = handleError(
            error,
            during: operation,
            file: file,
            function: function,
            line: line
        )
        return try recovery()
    }
}
