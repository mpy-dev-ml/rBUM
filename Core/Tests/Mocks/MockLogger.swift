//
//  MockLogger.swift
//  CoreTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import Foundation
@testable import Core

/// Mock logger for testing
class MockLogger: LoggerProtocol {
    var debugMessages: [(message: String, privacy: LogPrivacy)] = []
    var infoMessages: [(message: String, privacy: LogPrivacy)] = []
    var errorMessages: [(message: String, privacy: LogPrivacy)] = []
    
    func debug(_ message: String, privacy: LogPrivacy) {
        debugMessages.append((message, privacy))
    }
    
    func info(_ message: String, privacy: LogPrivacy) {
        infoMessages.append((message, privacy))
    }
    
    func error(_ message: String, privacy: LogPrivacy) {
        errorMessages.append((message, privacy))
    }
}
