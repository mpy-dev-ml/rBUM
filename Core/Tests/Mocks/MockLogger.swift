//
//  MockLogger.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation
import os.log

/// Mock logger for testing
class MockLogger: LoggerProtocol {
    func warning(_ message: String, file: String, function: String, line: Int) {
        warningMessages.append(LogMessage(message: message, file: file, function: function, line: line))
    }

    struct LogMessage {
        let message: String
        let file: String
        let function: String
        let line: Int
    }

    var debugMessages: [LogMessage] = []
    var infoMessages: [LogMessage] = []
    var warningMessages: [LogMessage] = []
    var errorMessages: [LogMessage] = []

    func debug(_ message: String, file: String, function: String, line: Int) {
        debugMessages.append(LogMessage(message: message, file: file, function: function, line: line))
    }

    func info(_ message: String, file: String, function: String, line: Int) {
        infoMessages.append(LogMessage(message: message, file: file, function: function, line: line))
    }

    func error(_ message: String, file: String, function: String, line: Int) {
        errorMessages.append(LogMessage(message: message, file: file, function: function, line: line))
    }
}
