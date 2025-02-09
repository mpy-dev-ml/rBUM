import Foundation

/// Manages XPC connection lifecycle and recovery
@available(macOS 13.0, *)
public actor XPCConnectionManager {
    // MARK: - Properties
    
    /// The current state of the XPC connection.
    /// This property is used to track the connection's lifecycle and determine the appropriate actions to take.
    private(set) var state: XPCConnectionState
    
    /// The active XPC connection instance.
    /// This property is used to interact with the XPC service and perform operations.
    private var connection: NSXPCConnection?
    
    /// The logger instance used for logging events and errors.
    /// This property is used to provide logging functionality throughout the class.
    private let logger: LoggerProtocol
    
    /// The security service instance used for validating the XPC connection.
    /// This property is used to ensure the security and integrity of the XPC connection.
    private let securityService: SecurityServiceProtocol
    
    /// The delegate instance that receives notifications about changes to the XPC connection state.
    /// This property is used to notify the delegate about changes to the connection state.
    private weak var delegate: XPCConnectionStateDelegate?
    
    /// The recovery task instance used to recover the XPC connection in case of failures.
    /// This property is used to manage the recovery process and ensure the connection is re-established.
    private var recoveryTask: Task<Void, Never>?
    
    /// The timer instance used to perform periodic health checks on the XPC connection.
    /// This property is used to ensure the connection remains healthy and functional.
    private var healthCheckTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initializes a new XPC connection manager
    /// - Parameters:
    ///   - logger: Logger instance for tracking connection events
    ///   - securityService: Service for handling security-related operations
    ///   - delegate: Delegate instance for receiving connection state updates
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        delegate: XPCConnectionStateDelegate? = nil
    ) {
        self.logger = logger
        self.securityService = securityService
        self.delegate = delegate
        self.state = .connecting
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Connection Management
    
    /// Establish XPC connection
    public func establishConnection() async throws -> NSXPCConnection {
        if case .active = state, let connection = connection {
            return connection
        }
        
        updateState(.connecting)
        
        do {
            let newConnection = try await createConnection()
            self.connection = newConnection
            updateState(.active)
            startHealthCheck()
            return newConnection
        } catch {
            updateState(.failed(error))
            throw error
        }
    }
    
    /// Handle connection interruption
    public func handleInterruption() {
        logger.warning("XPC connection interrupted", privacy: .public)
        updateState(.interrupted(Date()))
        startRecovery()
    }
    
    /// Handle connection invalidation
    public func handleInvalidation() {
        logger.error("XPC connection invalidated", privacy: .public)
        updateState(.invalidated(Date()))
        startRecovery()
    }
    
    // MARK: - Private Methods
    
    private func createConnection() async throws -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        
        // Configure interfaces
        connection.remoteObjectInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: ResticXPCProtocol.self)
        
        // Set up security
        connection.auditSessionIdentifier = au_session_self()
        
        // Configure handlers
        connection.interruptionHandler = { [weak self] in
            Task { await self?.handleInterruption() }
        }
        
        connection.invalidationHandler = { [weak self] in
            Task { await self?.handleInvalidation() }
        }
        
        // Validate connection
        guard await securityService.validateXPCConnection(connection) else {
            throw ResticXPCError.connectionValidationFailed
        }
        
        connection.resume()
        return connection
    }
    
    private func startRecovery() {
        guard state.canRecover else {
            logger.error("Connection cannot be recovered in current state: \(state)", privacy: .public)
            return
        }
        
        recoveryTask?.cancel()
        recoveryTask = Task {
            var attempt = 1
            let startTime = Date()
            
            while !Task.isCancelled {
                guard Date().timeIntervalSince(startTime) < XPCConnectionState.recoveryTimeout else {
                    updateState(.failed(ResticXPCError.recoveryTimeout))
                    return
                }
                
                updateState(.recovering(attempt: attempt, since: startTime))
                
                do {
                    _ = try await establishConnection()
                    logger.info("Connection recovered after \(attempt) attempts", privacy: .public)
                    return
                } catch {
                    logger.error("Recovery attempt \(attempt) failed: \(error.localizedDescription)", privacy: .public)
                    attempt += 1
                    
                    if attempt > XPCConnectionState.maxRecoveryAttempts {
                        updateState(.failed(ResticXPCError.recoveryFailed))
                        return
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(XPCConnectionState.recoveryDelay * 1_000_000_000))
                }
            }
        }
    }
    
    private func startHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() async {
        guard case .active = state, let connection = connection else { return }
        
        do {
            let remote = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
                Task { await self?.handleHealthCheckError(error) }
            } as? ResticXPCProtocol
            
            guard let remote = remote else {
                throw ResticXPCError.invalidRemoteObject
            }
            
            let isHealthy = try await remote.ping()
            if !isHealthy {
                logger.warning("Health check failed", privacy: .public)
                handleInterruption()
            }
        } catch {
            logger.error("Health check error: \(error.localizedDescription)", privacy: .public)
            handleHealthCheckError(error)
        }
    }
    
    private func handleHealthCheckError(_ error: Error) {
        logger.error("Health check error: \(error.localizedDescription)", privacy: .public)
        handleInterruption()
    }
    
    private func updateState(_ newState: XPCConnectionState) {
        let oldState = state
        state = newState
        delegate?.connectionStateDidChange(from: oldState, to: newState)
        
        NotificationCenter.default.post(
            name: .xpcConnectionStateChanged,
            object: nil,
            userInfo: [
                "oldState": oldState,
                "newState": newState
            ]
        )
    }
    
    private func cleanup() {
        recoveryTask?.cancel()
        recoveryTask = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        connection?.invalidate()
        connection = nil
    }
}
