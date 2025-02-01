//
//  TestMocks.swift
//  TestMocksModule
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation

/// Container for all test mock implementations
public enum TestMocks {
    /// Mock implementation of UserDefaults for testing
    public final class MockUserDefaults: UserDefaults {
        public var storage: [String: Any] = [:]
        
        public init() {
            super.init(suiteName: "TestMocks")!
        }
        
        public override func set(_ value: Any?, forKey defaultName: String) {
            if let value = value {
                storage[defaultName] = value
            } else {
                storage.removeValue(forKey: defaultName)
            }
        }
        
        public override func object(forKey defaultName: String) -> Any? {
            storage[defaultName]
        }
        
        public override func removeObject(forKey defaultName: String) {
            storage.removeValue(forKey: defaultName)
        }
        
        public func reset() {
            storage.removeAll()
        }
    }

    /// Mock implementation of FileManager for testing
    public final class MockFileManager: FileManager {
        public var files: [String: Bool] = [:]
        
        public override init() {
            super.init()
        }
        
        public override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
            files[path] ?? false
        }
        
        public func addFile(_ path: String) {
            files[path] = true
        }
        
        public func reset() {
            files.removeAll()
        }
    }

    /// Mock implementation of NotificationCenter for testing
    public final class MockNotificationCenter: NotificationCenter, @unchecked Sendable {
        public var postCalled = false
        public var lastNotification: Notification?
        
        public override init() {
            super.init()
        }
        
        public override func post(_ notification: Notification) {
            postCalled = true
            lastNotification = notification
        }
        
        public func reset() {
            postCalled = false
            lastNotification = nil
        }
    }
}
