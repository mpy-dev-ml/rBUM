import XCTest
@testable import Core
@testable import rBUM

@_exported import struct Core.LogMetadataValue
@_exported import enum Core.LogPrivacy

class MockLogger: LoggerProtocol {
    var messages: [String] = []
    var metadata: [[String: LogMetadataValue]] = []
    var privacyLevels: [LogPrivacy] = []

    func debug(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file _: String = #file,
        function _: String = #function,
        line _: Int = #line
    ) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        privacyLevels.append(privacy)
    }

    func info(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file _: String = #file,
        function _: String = #function,
        line _: Int = #line
    ) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        privacyLevels.append(privacy)
    }

    func warning(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file _: String = #file,
        function _: String = #function,
        line _: Int = #line
    ) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        privacyLevels.append(privacy)
    }

    func error(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file _: String = #file,
        function _: String = #function,
        line _: Int = #line
    ) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        privacyLevels.append(privacy)
    }
}
