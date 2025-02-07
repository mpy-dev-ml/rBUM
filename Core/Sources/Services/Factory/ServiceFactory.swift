//
//  ServiceFactory.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Factory for creating services with appropriate implementations based on build configuration
///
/// The ServiceFactory provides a centralized way to create services with the appropriate
/// implementation based on the current build configuration and settings. It supports:
/// - Development vs Production implementations
/// - Debug vs Release builds
/// - Feature flags and configuration
/// - Dependency injection
///
/// Example usage:
/// ```swift
/// // Create services
/// let logger = LoggerFactory.createLogger(category: .security)
/// let security = ServiceFactory.createSecurityService(logger: logger)
/// let keychain = ServiceFactory.createKeychainService(logger: logger)
///
/// // Configure factory
/// ServiceFactory.configuration = .init(
///     developmentEnabled: true,
///     debugLoggingEnabled: true
/// )
/// ```
///
/// Implementation notes:
/// 1. Uses conditional compilation for debug/release builds
/// 2. Supports feature flags via configuration
/// 3. Provides dependency injection
/// 4. Manages service lifecycles
public enum ServiceFactory {
    // MARK: - Properties
    
    /// Development configuration for debug builds
    static let developmentConfiguration = DevelopmentConfiguration()
}
