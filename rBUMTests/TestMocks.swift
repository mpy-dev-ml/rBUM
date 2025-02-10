import XCTest
@testable import Core
@testable import rBUM

@_exported import struct Core.LogMetadataValue

// Re-export Core types
@_exported import enum Core.LogPrivacy

// Re-export mock implementations
@_exported import MockKeychainService
@_exported import MockLogger
@_exported import MockXPCService

// Re-export test utilities
@_exported import TestFileUtilities
@_exported import TestRepository

// MARK: - Type Re-exports

/// A mock implementation of the LoggerProtocol for testing purposes
public typealias MockLogger = Utilities.MockLogger

/// A mock implementation of the SecurityServiceProtocol for testing purposes
public typealias MockSecurityService = Utilities.MockSecurityService

/// A mock implementation of the ResticXPCServiceProtocol for testing purposes
public typealias MockXPCService = Utilities.MockXPCService

/// A mock implementation of the KeychainServiceProtocol for testing purposes
public typealias MockKeychainService = Utilities.MockKeychainService

/// A test repository implementation for testing purposes
public typealias TestRepository = Utilities.TestRepository
