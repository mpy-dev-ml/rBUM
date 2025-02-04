import Foundation
import os.log

// MARK: - Base Service Support

/// Base class providing common service functionality
public class BaseService: LoggingService {
    public let logger: LoggerProtocol
    
    public init(logger: LoggerProtocol) {
        self.logger = logger
    }
    
    /// Execute an operation with retry logic
    public func withRetry<T>(
        attempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: String,
        action: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                return try await action()
            } catch {
                lastError = error
                logger.error("Attempt \(attempt) of \(operation) failed: \(error.localizedDescription)")
                if attempt < attempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? ServiceError.operationFailed
    }
}

/// Base class for services requiring sandbox compliance
public class BaseSandboxedService: BaseService, SandboxedService {
    public let securityService: SecurityServiceProtocol
    
    public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol) {
        self.securityService = securityService
        super.init(logger: logger)
    }
    
    public func startAccessing(_ url: URL) -> Bool {
        securityService.startAccessing(url)
    }
    
    public func stopAccessing(_ url: URL) {
        securityService.stopAccessing(url)
    }
}

// MARK: - Service Factory Support

/// Factory protocol for creating services
public protocol ServiceFactory {
    func createLogger(category: String) -> LoggerProtocol
    func createSecurityService() -> SecurityServiceProtocol
    func createKeychainService() -> KeychainServiceProtocol
    func createResticService() -> ResticServiceProtocol
}

/// Default implementation of ServiceFactory
public class DefaultServiceFactory: ServiceFactory {
    public static let shared = DefaultServiceFactory()
    
    private init() {}
    
    public func createLogger(category: String) -> LoggerProtocol {
        LoggerFactory.createLogger(category: category)
    }
    
    public func createSecurityService() -> SecurityServiceProtocol {
        let xpcService = ResticXPCService(
            logger: createLogger(category: "ResticXPCService"),
            securityService: SecurityService(
                logger: createLogger(category: "SecurityService"),
                xpcService: nil  // This will create a new XPC connection
            )
        )
        
        return SecurityService(
            logger: createLogger(category: "SecurityService"),
            xpcService: xpcService
        )
    }
    
    public func createKeychainService() -> KeychainServiceProtocol {
        KeychainService(
            logger: createLogger(category: "KeychainService"),
            securityService: createSecurityService()
        )
    }
    
    public func createResticService() -> ResticServiceProtocol {
        ResticXPCService(
            logger: createLogger(category: "ResticService"),
            securityService: createSecurityService()
        )
    }
}

// MARK: - Service Registration and Lifecycle

/// Service lifecycle states
public enum ServiceState {
    case uninitialized
    case initializing
    case ready
    case error(Error)
    case shutdown
}

/// Protocol for services that need lifecycle management
public protocol LifecycleManaged {
    var state: ServiceState { get }
    func initialize() async throws
    func shutdown() async
}

/// Base implementation of lifecycle management
public extension LifecycleManaged where Self: LoggingService {
    func initialize() async throws {
        logger.info("Initializing service...")
        // Override in concrete implementations
    }
    
    func shutdown() async {
        logger.info("Shutting down service...")
        // Override in concrete implementations
    }
}

// MARK: - Service Error Handling

public enum ServiceError: LocalizedError {
    case operationFailed
    case notInitialized
    case alreadyInitialized
    case invalidState(String)
    case dependencyError(String)
    
    public var errorDescription: String? {
        switch self {
        case .operationFailed:
            return "The operation failed to complete"
        case .notInitialized:
            return "Service is not initialized"
        case .alreadyInitialized:
            return "Service is already initialized"
        case .invalidState(let state):
            return "Invalid service state: \(state)"
        case .dependencyError(let dependency):
            return "Dependency error: \(dependency)"
        }
    }
}

// MARK: - Service Dependencies

/// Protocol for managing service dependencies
public protocol DependencyProvider {
    func resolve<T>() -> T?
    func register<T>(_ instance: T)
}

/// Simple dependency container
public class ServiceContainer: DependencyProvider {
    public static let shared = ServiceContainer()
    
    private var services: [String: Any] = [:]
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.serviceContainer", attributes: .concurrent)
    
    private init() {}
    
    public func resolve<T>() -> T? {
        queue.sync {
            services[String(describing: T.self)] as? T
        }
    }
    
    public func register<T>(_ instance: T) {
        queue.async(flags: .barrier) {
            self.services[String(describing: T.self)] = instance
        }
    }
}

// MARK: - Service Configuration

/// Protocol for configurable services
public protocol Configurable {
    associatedtype Configuration
    func configure(with config: Configuration) throws
}

/// Base configuration support
public extension Configurable where Self: LoggingService {
    func configure(with config: Configuration) throws {
        logger.info("Configuring service...")
        // Override in concrete implementations
    }
}

// MARK: - Service Monitoring

/// Protocol for services that support health monitoring
public protocol HealthCheckable {
    var isHealthy: Bool { get }
    func performHealthCheck() async -> Bool
}

/// Base implementation of health monitoring
public extension HealthCheckable where Self: LoggingService {
    func performHealthCheck() async -> Bool {
        logger.info("Performing health check...")
        return isHealthy
    }
}

// MARK: - Service Extensions

public extension LoggingService {
    /// Measure and log performance metrics
    func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        logger.info("\(operation) took \(String(format: "%.3f", duration))s")
        return result
    }
    
    /// Measure and log async performance metrics
    func measure<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        logger.info("\(operation) took \(String(format: "%.3f", duration))s")
        return result
    }
}
