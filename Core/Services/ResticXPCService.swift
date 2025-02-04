import Foundation
import Security
import os.log

/// XPC service for executing Restic commands outside the sandbox
@objc public final class ResticXPCService: NSObject, ResticXPCServiceProtocol {
    private let serviceName: String
    private let logger: LoggerProtocol
    private var connection: NSXPCConnection?
    
    public init(
        serviceName: String = "dev.mpy.rBUM.ResticXPCService",
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "ResticXPCService")
    ) {
        self.serviceName = serviceName
        self.logger = logger
        super.init()
    }
    
    deinit {
        disconnect()
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ResticXPCService else { return false }
        return serviceName == other.serviceName
    }
    
    public override var hash: Int {
        return serviceName.hash
    }
    
    public override var description: String {
        return "ResticXPCService(serviceName: \(serviceName))"
    }
    
    @objc public func connect() async throws {
        logger.debug("Connecting to XPC service", file: #file, function: #function, line: #line)
        
        guard connection == nil else {
            logger.debug("Already connected to XPC service", file: #file, function: #function, line: #line)
            return
        }
        
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: ResticXPCServiceProtocol.self)
        connection.resume()
        
        self.connection = connection
        logger.info("Connected to XPC service", file: #file, function: #function, line: #line)
    }
    
    private func disconnect() {
        logger.debug("Disconnecting from XPC service", file: #file, function: #function, line: #line)
        
        connection?.invalidate()
        connection = nil
        
        logger.info("Disconnected from XPC service", file: #file, function: #function, line: #line)
    }
    
    @objc public func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult {
        logger.debug("Executing command: \(command)", file: #file, function: #function, line: #line)
        
        guard let connection = connection else {
            logger.error("Not connected to XPC service", file: #file, function: #function, line: #line)
            throw SecurityError.xpcConnectionFailed("Not connected to XPC service")
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("XPC connection error: \(error.localizedDescription)", file: #file, function: #function, line: #line)
        } as? ResticXPCServiceProtocol
        
        guard let proxy = proxy else {
            logger.error("Failed to get XPC proxy", file: #file, function: #function, line: #line)
            throw SecurityError.xpcServiceError("Failed to get XPC proxy")
        }
        
        do {
            let result = try await proxy.executeCommand(command, withBookmark: bookmark)
            logger.debug("Command execution completed", file: #file, function: #function, line: #line)
            return result
        } catch {
            logger.error("Command execution failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.xpcServiceError("Command execution failed: \(error.localizedDescription)")
        }
    }
    
    @objc public func startAccessing(_ url: URL) -> Bool {
        logger.debug("Starting resource access: \(url.path)", file: #file, function: #function, line: #line)
        let success = url.startAccessingSecurityScopedResource()
        if success {
            logger.debug("Successfully started resource access", file: #file, function: #function, line: #line)
        } else {
            logger.error("Failed to start resource access", file: #file, function: #function, line: #line)
        }
        return success
    }
    
    @objc public func stopAccessing(_ url: URL) {
        logger.debug("Stopping resource access: \(url.path)", file: #file, function: #function, line: #line)
        url.stopAccessingSecurityScopedResource()
        logger.debug("Stopped resource access", file: #file, function: #function, line: #line)
    }
    
    @objc public func validatePermissions() async throws -> Bool {
        logger.debug("Validating permissions", file: #file, function: #function, line: #line)
        
        // For now, just check if we can connect
        do {
            try await connect()
            logger.info("Permissions validated successfully", file: #file, function: #function, line: #line)
            return true
        } catch {
            logger.error("Permission validation failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.xpcValidationFailed("Permission validation failed: \(error.localizedDescription)")
        }
    }
}
