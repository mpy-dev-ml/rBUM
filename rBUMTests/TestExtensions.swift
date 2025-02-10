import XCTest
@testable import Core
@testable import rBUM

extension XCTestCase {
    /// Waits for a condition to be true with a timeout
    /// - Parameters:
    ///   - timeout: The timeout duration
    ///   - description: Description of what we're waiting for
    ///   - condition: The condition to wait for
    /// - Throws: Error if timeout is reached
    func wait(timeout: TimeInterval = 5.0, description: String, for condition: @escaping () -> Bool) throws {
        let expectation = expectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                expectation.fulfill()
                timer.invalidate()
            }
        }
        defer { timer.invalidate() }
        wait(for: [expectation], timeout: timeout)
    }

    /// Asserts that a closure throws an error
    /// - Parameters:
    ///   - expectedError: The expected error type
    ///   - closure: The closure to execute
    /// - Throws: Error if assertion fails
    func assertThrows<T: Error>(_ expectedError: T.Type, closure: () throws -> Void) throws {
        var thrownError: Error?
        XCTAssertThrowsError(try closure()) { error in
            thrownError = error
        }
        XCTAssertTrue(thrownError is T, "Expected error of type \(T.self), but got \(type(of: thrownError))")
    }
}
