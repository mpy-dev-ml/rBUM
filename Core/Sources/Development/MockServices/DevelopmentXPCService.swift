//
//  DevelopmentXPCService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//

import Foundation

/// Development mock implementation of ResticXPCProtocol
/// Provides simulated XPC service behaviour for development
public final class DevelopmentXPCService: ResticXPCProtocol {
    // MARK: - Properties
    private let logger: LoggerProtocol
    private let queue = DispatchQueue(label: "dev.mpy.rBUM.developmentXPC", attributes: .concurrent)
    
    /// Configuration for simulating XPC behaviour
    public struct Configuration {
        /// Whether to simulate command execution failures
        public var shouldSimulateCommandFailures: Bool
        /// Whether to simulate connection failures
        public var shouldSimulateConnectionFailures: Bool
        /// Whether to simulate timeout failures
        public var shouldSimulateTimeoutFailures: Bool
        /// Artificial delay for operations (seconds)
        public var artificialDelay: TimeInterval
        /// Simulated command execution time (seconds)
        public var commandExecutionTime: TimeInterval
        
        public init(
            shouldSimulateCommandFailures: Bool = false,
            shouldSimulateConnectionFailures: Bool = false,
            shouldSimulateTimeoutFailures: Bool = false,
            artificialDelay: TimeInterval = 0,
            commandExecutionTime: TimeInterval = 0.5
        ) {
            self.shouldSimulateCommandFailures = shouldSimulateCommandFailures
            self.shouldSimulateConnectionFailures = shouldSimulateConnectionFailures
            self.shouldSimulateTimeoutFailures = shouldSimulateTimeoutFailures
            self.artificialDelay = artificialDelay
            self.commandExecutionTime = commandExecutionTime
        }
    }
    
    private var configuration: Configuration
    
    // MARK: - Initialization
    public init(
        logger: LoggerProtocol,
        configuration: Configuration = Configuration()
    ) {
        self.logger = logger
        self.configuration = configuration
        
        logger.info(
            "Initialised DevelopmentXPCService with configuration: \(String(describing: configuration))",
            file: #file,
            function: #function,
            line: #line
        )
    }
    
    // MARK: - ResticXPCProtocol Implementation
    public func executeCommand(
        _ command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData],
        timeout: TimeInterval,
        auditSessionId: au_asid_t,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        if configuration.shouldSimulateConnectionFailures {
            logger.error(
                "Simulating connection failure for command: \(command)",
                file: #file,
                function: #function,
                line: #line
            )
            completion(nil)
            return
        }
        
        queue.async {
            // Simulate artificial delay
            if self.configuration.artificialDelay > 0 {
                Thread.sleep(forTimeInterval: self.configuration.artificialDelay)
            }
            
            // Simulate command execution time
            Thread.sleep(forTimeInterval: self.configuration.commandExecutionTime)
            
            // Simulate timeout if execution time exceeds timeout
            if self.configuration.commandExecutionTime > timeout || self.configuration.shouldSimulateTimeoutFailures {
                self.logger.error(
                    "Simulating timeout failure for command: \(command)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                completion(nil)
                return
            }
            
            // Simulate command failure if configured
            if self.configuration.shouldSimulateCommandFailures {
                self.logger.error(
                    "Simulating command failure for: \(command)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                completion([
                    "success": false,
                    "error": "Simulated command failure",
                    "exitCode": 1
                ])
                return
            }
            
            // Simulate successful command execution
            self.logger.info(
                "Successfully executed command: \(command)",
                file: #file,
                function: #function,
                line: #line
            )
            completion([
                "success": true,
                "output": "Simulated output for command: \(command)",
                "exitCode": 0
            ])
        }
    }
    
    public func ping(auditSessionId: au_asid_t, completion: @escaping (Bool) -> Void) {
        if configuration.shouldSimulateConnectionFailures {
            logger.error(
                "Simulating connection failure for ping",
                file: #file,
                function: #function,
                line: #line
            )
            completion(false)
            return
        }
        
        queue.async {
            // Simulate artificial delay
            if self.configuration.artificialDelay > 0 {
                Thread.sleep(forTimeInterval: self.configuration.artificialDelay)
            }
            
            self.logger.info(
                "Successfully responded to ping",
                file: #file,
                function: #function,
                line: #line
            )
            completion(true)
        }
    }
}
