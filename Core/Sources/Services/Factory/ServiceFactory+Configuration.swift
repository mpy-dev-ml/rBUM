import Foundation

extension ServiceFactory {
    // MARK: - Configuration
    
    /// Configuration for service factory
    public struct Configuration {
        /// Whether to enable development features
        public let developmentEnabled: Bool
        
        /// Whether to enable debug logging
        public let debugLoggingEnabled: Bool
        
        /// Whether to enable performance metrics
        public let metricsEnabled: Bool
        
        /// Whether to enable circuit breakers
        public let circuitBreakersEnabled: Bool
        
        /// Default configuration for the current build
        public static let `default` = Configuration(
            #if DEBUG
            developmentEnabled: true,
            debugLoggingEnabled: true,
            metricsEnabled: true,
            circuitBreakersEnabled: false
            #else
            developmentEnabled: false,
            debugLoggingEnabled: false,
            metricsEnabled: true,
            circuitBreakersEnabled: true
            #endif
        )
        
        /// Creates a new configuration
        /// - Parameters:
        ///   - developmentEnabled: Whether to enable development features
        ///   - debugLoggingEnabled: Whether to enable debug logging
        ///   - metricsEnabled: Whether to enable performance metrics
        ///   - circuitBreakersEnabled: Whether to enable circuit breakers
        public init(
            developmentEnabled: Bool,
            debugLoggingEnabled: Bool,
            metricsEnabled: Bool,
            circuitBreakersEnabled: Bool
        ) {
            self.developmentEnabled = developmentEnabled
            self.debugLoggingEnabled = debugLoggingEnabled
            self.metricsEnabled = metricsEnabled
            self.circuitBreakersEnabled = circuitBreakersEnabled
        }
    }
    
    /// Current configuration for the service factory
    public static var configuration: Configuration = .default
}
