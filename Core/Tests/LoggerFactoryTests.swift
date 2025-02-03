//
//  LoggerFactoryTests.swift
//  CoreTests
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest
@testable import Core

final class LoggerFactoryTests: XCTestCase {
    func testCreateLogger() {
        let logger = LoggerFactory.createLogger(category: "Test")
        XCTAssertNotNil(logger)
        XCTAssertTrue(logger is DefaultLogger)
    }
}
