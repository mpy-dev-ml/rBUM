//
//  MockLogger.swift
//  Core
//
//  First created: 6 February 2025
//  Last updated: 7 February 2025
//

import Foundation
import os.log

/// Mock logger for testing
public final class MockLogger: LoggerProtocol {
    public struct LogMessage {
        public let message: String
        public let metadata: [String: LogMetadataValue]
        public let privacy: LogPrivacy
        public let file: String
        public let function: String
        public let line: Int
    }

    public private(set) var messages: [LogMessage] = []

    public init() {}

    public func debug(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        messages.append(LogMessage(
            message: message,
            metadata: metadata ?? [:],
            privacy: privacy,
            file: file,
            function: function,
            line: line
        ))
    }

    public func info(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        messages.append(LogMessage(
            message: message,
            metadata: metadata ?? [:],
            privacy: privacy,
            file: file,
            function: function,
            line: line
        ))
    }

    public func warning(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        messages.append(LogMessage(
            message: message,
            metadata: metadata ?? [:],
            privacy: privacy,
            file: file,
            function: function,
            line: line
        ))
    }

    public func error(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        messages.append(LogMessage(
            message: message,
            metadata: metadata ?? [:],
            privacy: privacy,
            file: file,
            function: function,
            line: line
        ))
    }

    public func containsMessage(_ pattern: String) -> Bool {
        messages.contains { $0.message.contains(pattern) }
    }

    public func clear() {
        messages.removeAll()
    }
}
