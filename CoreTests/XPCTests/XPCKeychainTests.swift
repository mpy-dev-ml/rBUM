//
//  XPCKeychainTests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
@testable import Core
@testable import rBUM
import XCTest

final class XPCKeychainTests: XCTestCase {
    private var keychainService: KeychainService!
    private var mockLogger: MockLogger!
    private let testAccessGroup = "dev.mpy.rBUM.test"
    private let testKey = "test_key"
    private let testData = "test_data".data(using: .utf8)!

    override func setUp() async throws {
        try await super.setUp()
        mockLogger = MockLogger()
        keychainService = KeychainService(logger: mockLogger)
        try keychainService.configureXPCSharing(accessGroup: testAccessGroup)
    }

    override func tearDown() async throws {
        try? keychainService.delete(for: testKey, accessGroup: testAccessGroup)
        keychainService = nil
        mockLogger = nil
        try await super.tearDown()
    }

    // MARK: - XPC Access Group Tests

    func testXPCAccessGroupConfiguration() throws {
        // Test access group configuration
        XCTAssertNoThrow(try keychainService.configureXPCSharing(accessGroup: testAccessGroup))

        // Verify access group validation
        XCTAssertTrue(try keychainService.validateXPCAccess(accessGroup: testAccessGroup))
    }

    func testInvalidAccessGroup() throws {
        // Test invalid access group
        let invalidGroup = ""
        XCTAssertThrowsError(try keychainService.configureXPCSharing(accessGroup: invalidGroup))
    }

    // MARK: - Shared Access Tests

    func testSharedKeychainAccess() throws {
        // Save with access group
        try keychainService.save(testData, for: testKey, accessGroup: testAccessGroup)

        // Retrieve with access group
        let retrieved = try keychainService.retrieve(for: testKey, accessGroup: testAccessGroup)
        XCTAssertEqual(retrieved, testData)
    }

    func testAccessGroupIsolation() throws {
        // Save with different access groups
        let otherGroup = "dev.mpy.rBUM.other"
        try keychainService.save(testData, for: testKey, accessGroup: testAccessGroup)

        // Attempt to retrieve with different access group
        let retrieved = try keychainService.retrieve(for: testKey, accessGroup: otherGroup)
        XCTAssertNil(retrieved)
    }

    // MARK: - Error Handling Tests

    func testDuplicateItemHandling() throws {
        // Test handling of duplicate items
        try keychainService.save(testData, for: testKey, accessGroup: testAccessGroup)
        XCTAssertThrowsError(try keychainService.save(testData, for: testKey, accessGroup: testAccessGroup))
    }

    func testItemDeletion() throws {
        // Save and delete item
        try keychainService.save(testData, for: testKey, accessGroup: testAccessGroup)
        XCTAssertNoThrow(try keychainService.delete(for: testKey, accessGroup: testAccessGroup))

        // Verify deletion
        let retrieved = try keychainService.retrieve(for: testKey, accessGroup: testAccessGroup)
        XCTAssertNil(retrieved)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentAccess() async throws {
        // Test concurrent keychain operations
        async let save1 = Task {
            try keychainService.save(testData, for: "\(testKey)_1", accessGroup: testAccessGroup)
        }
        async let save2 = Task {
            try keychainService.save(testData, for: "\(testKey)_2", accessGroup: testAccessGroup)
        }

        try await [save1.value, save2.value]

        // Verify both saves succeeded
        let item1 = try keychainService.retrieve(for: "\(testKey)_1", accessGroup: testAccessGroup)
        let item2 = try keychainService.retrieve(for: "\(testKey)_2", accessGroup: testAccessGroup)
        XCTAssertNotNil(item1)
        XCTAssertNotNil(item2)
    }

    // MARK: - XPC Service Validation Tests

    func testXPCServiceValidation() throws {
        // Test XPC service validation with valid configuration
        XCTAssertTrue(try keychainService.validateXPCAccess(accessGroup: testAccessGroup))

        // Test with invalid access group
        XCTAssertThrowsError(try keychainService.validateXPCAccess(accessGroup: ""))
    }
}
