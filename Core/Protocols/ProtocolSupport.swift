import Foundation
import os.log

// MARK: - Logger Protocol Support

public extension LoggerProtocol {
    /// Default implementation for debug logging with file info
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }
    
    /// Default implementation for info logging with file info
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }
    
    /// Default implementation for error logging with file info
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, file: file, function: function, line: line)
    }
}

// MARK: - Sandbox Compliance Support

public extension SandboxCompliant {
    /// Default implementation for safe resource access
    func withSafeAccess<T>(to url: URL, perform action: () throws -> T) throws -> T {
        guard startAccessing(url) else {
            throw SandboxError.accessDenied
        }
        defer { stopAccessing(url) }
        return try action()
    }
    
    /// Default implementation for async safe resource access
    func withSafeAccess<T>(to url: URL, perform action: () async throws -> T) async throws -> T {
        guard startAccessing(url) else {
            throw SandboxError.accessDenied
        }
        defer { stopAccessing(url) }
        return try await action()
    }
}

// MARK: - Type Constraints

/// Protocol for services that require sandbox compliance
public protocol SandboxedService: SandboxCompliant {
    var securityService: SecurityServiceProtocol { get }
}

/// Protocol for services that require logging
public protocol LoggingService {
    var logger: LoggerProtocol { get }
}

/// Protocol for services that require both sandbox compliance and logging
public typealias SecureLoggingService = SandboxedService & LoggingService

// MARK: - Default Implementations for Common Service Requirements

public extension SandboxedService {
    /// Default implementation for checking bookmark validity
    func validateBookmark(_ bookmark: Data) throws -> URL {
        try securityService.validateBookmark(bookmark)
    }
    
    /// Default implementation for persisting bookmark
    func persistBookmark(for url: URL) throws -> Data {
        try securityService.persistBookmark(for: url)
    }
}

public extension LoggingService {
    /// Log an operation with timing information
    func logOperation<T>(_ name: String, level: OSLogType = .debug, perform operation: () throws -> T) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logger.info("\(name) completed in \(String(format: "%.3f", duration))s")
        }
        return try operation()
    }
    
    /// Log an async operation with timing information
    func logOperation<T>(_ name: String, level: OSLogType = .debug, perform operation: () async throws -> T) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logger.info("\(name) completed in \(String(format: "%.3f", duration))s")
        }
        return try await operation()
    }
}

// MARK: - Error Handling Support

public extension Error {
    /// Convert any error to a user-presentable format
    var userDescription: String {
        switch self {
        case let error as LocalizedError:
            return error.localizedDescription
        case let error as CustomStringConvertible:
            return error.description
        default:
            return String(describing: self)
        }
    }
}

// MARK: - Protocol Composition Helpers

/// Protocol for services that need file system access
public protocol FileSystemService: SandboxedService {
    func validatePath(_ path: String) -> Bool
    func resolvePath(_ path: String) -> URL?
}

/// Protocol for services that need keychain access
public protocol SecureStorageService: LoggingService {
    func secureStore(_ data: Data, for key: String) throws
    func retrieveSecureData(for key: String) throws -> Data
}

// MARK: - Default Implementation for Common Protocol Requirements

public extension FileSystemService {
    /// Default path validation
    func validatePath(_ path: String) -> Bool {
        !path.isEmpty && URL(fileURLWithPath: path).isFileURL
    }
    
    /// Default path resolution
    func resolvePath(_ path: String) -> URL? {
        guard validatePath(path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}

public extension SecureStorageService {
    /// Default secure data storage with logging
    func secureStore(_ data: Data, for key: String) throws {
        try logOperation("Storing secure data for \(key)") {
            // Implement actual storage logic in concrete types
            throw SandboxError.accessDenied
        }
    }
    
    /// Default secure data retrieval with logging
    func retrieveSecureData(for key: String) throws -> Data {
        try logOperation("Retrieving secure data for \(key)") {
            // Implement actual retrieval logic in concrete types
            throw SandboxError.accessDenied
        }
    }
}
