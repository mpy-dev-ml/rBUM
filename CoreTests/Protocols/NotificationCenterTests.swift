import XCTest
@testable import Core

final class NotificationCenterTests: XCTestCase {
    // MARK: - Properties

    private var notificationCenter: TestNotificationCenter!
    private var observer: TestObserver!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        notificationCenter = TestNotificationCenter()
        observer = TestObserver()
    }

    override func tearDown() async throws {
        notificationCenter = nil
        observer = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testPostNotification() throws {
        let name = Notification.Name("TestNotification")
        let object = NSString(string: "TestObject")
        let userInfo = ["key": "value"]

        let expectation = XCTestExpectation(description: "Notification received")

        notificationCenter.addObserver(forName: name, object: nil) { notification in
            XCTAssertEqual(notification.name, name)
            XCTAssertEqual(notification.object as? NSString, object)
            XCTAssertEqual(notification.userInfo as? [String: String], userInfo)
            expectation.fulfill()
        }

        notificationCenter.post(name: name, object: object, userInfo: userInfo)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAddAndRemoveObserver() throws {
        let name = Notification.Name("TestNotification")
        var notificationCount = 0

        let token = notificationCenter.addObserver(forName: name, object: nil) { _ in
            notificationCount += 1
        }

        notificationCenter.post(name: name, object: nil)
        XCTAssertEqual(notificationCount, 1)

        notificationCenter.removeObserver(token)
        notificationCenter.post(name: name, object: nil)
        XCTAssertEqual(notificationCount, 1) // Should not increase after removal
    }

    func testMultipleObservers() throws {
        let name = Notification.Name("TestNotification")
        var observer1Count = 0
        var observer2Count = 0

        let token1 = notificationCenter.addObserver(forName: name, object: nil) { _ in
            observer1Count += 1
        }

        let token2 = notificationCenter.addObserver(forName: name, object: nil) { _ in
            observer2Count += 1
        }

        notificationCenter.post(name: name, object: nil)

        XCTAssertEqual(observer1Count, 1)
        XCTAssertEqual(observer2Count, 1)

        notificationCenter.removeObserver(token1)
        notificationCenter.post(name: name, object: nil)

        XCTAssertEqual(observer1Count, 1) // Should not increase after removal
        XCTAssertEqual(observer2Count, 2)

        notificationCenter.removeObserver(token2)
    }

    func testObjectFilter() throws {
        let name = Notification.Name("TestNotification")
        let object1 = NSString(string: "Object1")
        let object2 = NSString(string: "Object2")
        var notificationCount = 0

        let token = notificationCenter.addObserver(forName: name, object: object1) { _ in
            notificationCount += 1
        }

        notificationCenter.post(name: name, object: object1)
        XCTAssertEqual(notificationCount, 1)

        notificationCenter.post(name: name, object: object2)
        XCTAssertEqual(notificationCount, 1) // Should not increase for different object

        notificationCenter.removeObserver(token)
    }

    func testConcurrentNotifications() throws {
        let name = Notification.Name("TestNotification")
        let expectation = XCTestExpectation(description: "Concurrent notifications")
        expectation.expectedFulfillmentCount = 100

        let token = notificationCenter.addObserver(forName: name, object: nil) { _ in
            expectation.fulfill()
        }

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            notificationCenter.post(name: name, object: nil)
        }

        wait(for: [expectation], timeout: 5.0)
        notificationCenter.removeObserver(token)
    }
}

// MARK: - Test Helpers

private final class TestObserver: NSObject {
    var notificationReceived = false

    @objc func handleNotification(_: Notification) {
        notificationReceived = true
    }
}

private final class TestNotificationCenter: NotificationCenterProtocol {
    private var observers: [NSObjectProtocol] = []
    private let queue = DispatchQueue(label: "com.rbum.testnotificationcenter", attributes: .concurrent)

    func addObserver(
        forName name: Notification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        let observer = NotificationCenter.default.addObserver(forName: name, object: obj, queue: queue, using: block)
        self.queue.async(flags: .barrier) {
            self.observers.append(observer)
        }
        return observer
    }

    func post(name aName: Notification.Name, object anObject: Any?, userInfo aUserInfo: [AnyHashable: Any]? = nil) {
        NotificationCenter.default.post(name: aName, object: anObject, userInfo: aUserInfo)
    }

    func removeObserver(_ observer: Any) {
        queue.async(flags: .barrier) {
            if let index = self.observers.firstIndex(where: { $0 === observer as AnyObject }) {
                self.observers.remove(at: index)
            }
        }
        NotificationCenter.default.removeObserver(observer)
    }
}
