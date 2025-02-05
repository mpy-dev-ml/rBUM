//
//  ResticXPCServiceTests.swift
//  rBUM
//
//  Created by Matthew Yeager on 05/02/2025.
//


import XCTest
import Testing
@testable import Core

struct ResticXPCServiceTests {
    // MARK: - Test Properties
    private var sut: ResticXPCService!
    private var mockLogger: MockLogger!
    private var mockSecurityService: MockSecurityService!
    
    // MARK: - Setup and Teardown
    mutating func setUp() {
        mockLogger = MockLogger()
        mockSecurityService = MockSecurityService()
        sut = ResticXPCService(logger: mockLogger, securityService: mockSecurityService)
    }
    
    mutating func tearDown() {
        sut = nil
        mockLogger = nil
        mockSecurityService = nil
    }
    
    // MARK: - Interface Version Tests
    @Test("Interface version validation succeeds with matching versions")
    func testInterfaceVersionValidation() async throws {
        setUp()
        defer { tearDown() }
        
        let expectation = XCTestExpectation(description: "Interface validation")
        var result: [String: Any]?
        
        // Test interface validation
        try await sut.validateInterface { response in
            result = response
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        guard let version = result?["version"] as? Int else {
            XCTFail("Version not found in response")
            return
        }
        
        #expect(version == 1)
    }
    
    // MARK: - Security Tests
    @Test("Audit session validation succeeds with valid session")
    func testAuditSessionValidation() async throws {
        setUp()
        defer { tearDown() }
        
        let auditSessionId = au_session_self()
        let expectation = XCTestExpectation(description: "Audit session validation")
        
        try await sut.ping(auditSessionId: auditSessionId) { success in
            #expect(success)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    @Test("Bookmark validation succeeds with valid bookmarks")
    func testBookmarkValidation() async throws {
        setUp()
        defer { tearDown() }
        
        let mockBookmark = NSData() // Mock bookmark data
        let bookmarks = ["testPath": mockBookmark]
        let auditSessionId = au_session_self()
        let expectation = XCTestExpectation(description: "Bookmark validation")
        
        try await sut.validateAccess(bookmarks: bookmarks, auditSessionId: auditSessionId) { result in
            guard let isValid = result?["valid"] as? Bool else {
                XCTFail("Invalid response format")
                return
            }
            #expect(isValid)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Command Execution Tests
    @Test("Command execution succeeds with valid parameters")
    func testCommandExecution() async throws {
        setUp()
        defer { tearDown() }
        
        let command = "/usr/bin/echo"
        let arguments = ["test"]
        let environment: [String: String] = [:]
        let workingDirectory = FileManager.default.temporaryDirectory.path
        let bookmarks: [String: NSData] = [:]
        let timeout: TimeInterval = 30.0
        let auditSessionId = au_session_self()
        
        let expectation = XCTestExpectation(description: "Command execution")
        
        try await sut.executeCommand(command,
                                   arguments: arguments,
                                   environment: environment,
                                   workingDirectory: workingDirectory,
                                   bookmarks: bookmarks,
                                   timeout: timeout,
                                   auditSessionId: auditSessionId) { result in
            guard let output = result?["output"] as? String else {
                XCTFail("Invalid response format")
                return
            }
            #expect(output.contains("test"))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Error Handling Tests
    @Test("Invalid audit session returns appropriate error")
    func testInvalidAuditSession() async throws {
        setUp()
        defer { tearDown() }
        
        let invalidAuditSessionId: au_asid_t = 0
        let expectation = XCTestExpectation(description: "Invalid audit session")
        
        try await sut.ping(auditSessionId: invalidAuditSessionId) { success in
            #expect(!success)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}