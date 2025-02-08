//
//  MockLoggerExtensions.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation

extension MockLogger {
    /// Logs a message with the specified metadata and privacy level
    func log(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        privacyLevels.append(privacy)
    }
    
    /// Verifies that a message was logged
    func verifyMessageLogged(
        _ message: String,
        metadata: [String: LogMetadataValue]? = nil,
        privacy: LogPrivacy = .public
    ) -> Bool {
        guard let index = messages.firstIndex(of: message) else {
            return false
        }
        
        if let expectedMetadata = metadata {
            guard self.metadata[index] == expectedMetadata else {
                return false
            }
        }
        
        return privacyLevels[index] == privacy
    }
}
