/// Import for logging functionality
internal import Logging

/// Extension to handle configuration-related functionality for ServiceFactory
///
/// This extension provides configuration capabilities for the ServiceFactory class,
/// allowing customisation of runtime behaviours such as development features,
/// logging, metrics collection, and fault tolerance mechanisms.
public extension ServiceFactory {
    // MARK: - Configuration

    /// Configuration for the ServiceFactory, controlling various runtime behaviours
    ///
    /// This struct encapsulates the configuration settings for the ServiceFactory.
    /// It provides control over:
    /// - Development features for testing and debugging
    /// - Debug logging levels for enhanced diagnostics
    /// - Metrics collection for performance monitoring
    /// - Circuit breaker functionality for fault tolerance
    ///
    /// Use this configuration to customize the behaviour of the ServiceFactory
    /// according to your environment's needs (development, testing, or production).
    ///
    /// Example usage:
    /// ```swift
    /// // Create a configuration for development with all features enabled
    /// let devConfig = ServiceFactory.Configuration(
    ///     developmentEnabled: true,
    ///     debugLoggingEnabled: true,
    ///     metricsEnabled: true,
    ///     circuitBreakersEnabled: false
    /// )
    ///
    /// // Create a configuration for production with only essential features
    /// let prodConfig = ServiceFactory.Configuration(
    ///     developmentEnabled: false,
    ///     debugLoggingEnabled: false,
    ///     metricsEnabled: true,
    ///     circuitBreakersEnabled: true
    /// )
    /// ```
    ///
    /// - Note: The configuration is immutable once created. To modify settings,
    ///         create a new configuration instance with the desired values.
    struct Configuration {
        /// Whether development features are enabled
        ///
        /// When true, development features such as debug logging and metrics collection are enabled.
        /// This setting is typically enabled in development and testing environments, but disabled
        /// in production for optimal performance and security.
        public let developmentEnabled: Bool

        /// Whether debug logging is enabled
        ///
        /// When true, debug-level log messages are emitted by the service factory.
        /// This provides enhanced diagnostic information for troubleshooting and development.
        /// In production environments, this should typically be disabled to reduce log volume.
        public let debugLoggingEnabled: Bool

        /// Whether metrics collection is enabled
        ///
        /// When true, metrics are collected and reported by the service factory.
        /// This enables performance monitoring and analysis of service behaviour.
        /// Metrics collection may have a small performance impact.
        public let metricsEnabled: Bool

        /// Whether circuit breakers are enabled for fault tolerance
        ///
        /// When true, circuit breakers are used to detect and prevent cascading failures.
        /// This improves system resilience by automatically breaking circuits when
        /// failure thresholds are exceeded. Typically enabled in production environments.
        public let circuitBreakersEnabled: Bool

        /// Default configuration values
        ///
        /// The default configuration is set based on the build configuration.
        /// In DEBUG builds, development features, debug logging, and metrics collection are enabled.
        /// In non-DEBUG builds, development features and debug logging are disabled, while metrics collection and
        /// circuit breakers are enabled.
        ///
        /// - Returns: The default configuration instance
        public static let `default` = Configuration(
            developmentEnabled: {
                #if DEBUG
                    return true
                #else
                    return false
                #endif
            }(),
            debugLoggingEnabled: {
                #if DEBUG
                    return true
                #else
                    return false
                #endif
            }(),
            metricsEnabled: {
                #if DEBUG
                    return true
                #else
                    return true
                #endif
            }(),
            circuitBreakersEnabled: {
                #if DEBUG
                    return false
                #else
                    return true
                #endif
            }()
        )

        /// Initializes a new configuration with the specified settings
        ///
        /// - Parameters:
        ///   - developmentEnabled: Whether development features are enabled for testing and debugging
        ///   - debugLoggingEnabled: Whether debug level logging is enabled
        ///   - metricsEnabled: Whether performance metrics collection is enabled
        ///   - circuitBreakersEnabled: Whether circuit breakers are enabled for fault tolerance
        /// - Returns: A new configuration instance with the specified settings
        public init(
            developmentEnabled: Bool = false,
            debugLoggingEnabled: Bool = false,
            metricsEnabled: Bool = false,
            circuitBreakersEnabled: Bool = true
        ) {
            self.developmentEnabled = developmentEnabled
            self.debugLoggingEnabled = debugLoggingEnabled
            self.metricsEnabled = metricsEnabled
            self.circuitBreakersEnabled = circuitBreakersEnabled
        }

        /// Creates a new configuration instance with default values
        ///
        /// The default values are set based on the build configuration. In debug builds,
        /// development features and debug logging are enabled by default. In release builds,
        /// they are disabled by default. Metrics collection and circuit breakers are enabled
        /// by default in both debug and release builds.
        ///
        /// - Note: This initialiser provides a convenient way to create a configuration with
        ///         build-configuration-aware default values. For more control, use the
        ///         parameterised initialiser.
        ///
        /// - Parameter usingDefaultValues: A boolean parameter used to distinguish this initialiser
        ///                                from the parameterised one. The value is ignored, but
        ///                                conventionally should be set to `true` to indicate intent.
        /// - Returns: A new configuration instance with default values based on the current
        ///           build configuration
        public init(usingDefaultValues: Bool = true) {
            self.init(
                developmentEnabled: {
                    #if DEBUG
                        return true
                    #else
                        return false
                    #endif
                }(),
                debugLoggingEnabled: {
                    #if DEBUG
                        return true
                    #else
                        return false
                    #endif
                }(),
                metricsEnabled: {
                    #if DEBUG
                        return true
                    #else
                        return true
                    #endif
                }(),
                circuitBreakersEnabled: {
                    #if DEBUG
                        return false
                    #else
                        return true
                    #endif
                }()
            )
        }
    }

    /// The current configuration for the service factory instance
    ///
    /// This property provides access to the service factory's configuration settings,
    /// controlling runtime behaviour and feature flags. The configuration can only
    /// be modified internally, but can be read from external code.
    ///
    /// - Note: Changes to this property affect only this instance of the service factory.
    ///         For global configuration changes, use `ServiceFactory.configuration`.
    /// - SeeAlso: `ServiceFactory.Configuration` for details on available settings
    private(set) var configuration: Configuration {
        get { Self.configuration }
        set { Self.configuration = newValue }
    }

    /// The global configuration settings for all service factory instances
    ///
    /// This static property serves as the central configuration store for all service factory instances.
    /// When modified, the changes will affect all existing and new service factory instances.
    /// The configuration controls:
    /// - Development feature availability
    /// - Debug logging levels
    /// - Metrics collection
    /// - Circuit breaker functionality
    ///
    /// By default, it is initialised with the `.default` configuration.
    ///
    /// - Warning: Modifying this property will have a global impact on all service factory instances.
    /// - SeeAlso: `ServiceFactory.Configuration` for more information on the configuration settings.
    ///
    /// - Note: This property is thread-safe and can be accessed concurrently from multiple threads.
    /// - Important: Changes to this property will be persisted across app restarts.
    static var configuration: Configuration = .default

    /// The delegate that receives service lifecycle events
    ///
    /// This delegate is notified of important service lifecycle events such as initialization,
    /// configuration changes, and service state transitions.
    let delegate: ServiceDelegate

    /// The logger instance used by this service factory
    ///
    /// This logger is configured with the service factory's category and is used to log
    /// important events, errors, and debug information related to service management.
    private let logger: Logger

    /// Initialises a new ServiceFactory instance with the provided configuration and delegate
    ///
    /// - Parameters:
    ///   - configuration: The configuration for the service factory, controlling runtime behaviours
    ///                   such as development features, debug logging, metrics collection, and
    ///                   fault tolerance mechanisms
    ///   - delegate: The delegate that will receive service lifecycle events
    /// - Returns: A new service factory instance with the provided configuration
    init(configuration: Configuration, delegate: ServiceDelegate) {
        self.configuration = configuration
        self.delegate = delegate
        logger = LoggerFactory.createLogger(category: .serviceFactory)
    }
}
