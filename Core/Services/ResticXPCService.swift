import Foundation
import Security

/// XPC service for executing Restic commands outside the sandbox
public final class ResticXPCService {
    /// Shared instance for XPC service access
    public static let shared = ResticXPCService()
    
    /// Connection to the XPC service
    private var connection: NSXPCConnection?
    private let logger: LoggerProtocol
    
    /// Service name for the XPC helper
    private let serviceName = "dev.mpy.rBUM.ResticHelper"
    
    private init(logger: LoggerProtocol = LoggerFactory.createLogger(category: "ResticXPCService")) {
        self.logger = logger
    }
    
    /// Get audit session ID from process info
    private func getAuditSessionID() -> au_asid_t {
        var asid: au_asid_t = AU_DEFAUDITSID
        if #available(macOS 11.0, *) {
            asid = audit_token_to_asid(ProcessInfo.processInfo.auditToken)
        }
        return asid
    }
    
    /// Ensure connection is established
    private func ensureConnection() throws {
        guard connection == nil else { return }
        
        logger.debug("Establishing XPC connection", file: #file, function: #function, line: #line)
        
        // Create connection to helper
        let connection = NSXPCConnection(serviceName: serviceName)
        
        // Configure interface
        let interface = NSXPCInterface(with: ResticXPCServiceProtocol.self)
        
        // Set allowed classes for secure coding
        interface.setClasses(
            NSSet(array: [ProcessResult.self, NSString.self, NSData.self, NSURL.self]) as! Set<AnyHashable>,
            for: #selector(ResticXPCServiceProtocol.executeCommand(_:withBookmark:)),
            argumentIndex: 1,
            ofReply: false
        )
        
        // Configure security attributes
        let securityAttributes: [String: Bool] = [
            NSXPCConnectionPrivileged: false,
            NSXPCConnectionPrivilegedAttribute: false
        ]
        connection.remoteObjectInterface = interface
        connection.exportedInterface = interface
        connection.auditSessionIdentifier = getAuditSessionID()
        
        for (key, value) in securityAttributes {
            connection.setValue(value, forKeyPath: key)
        }
        
        // Set up error handling
        connection.invalidationHandler = { [weak self] in
            self?.logger.error("XPC connection invalidated", file: #file, function: #function, line: #line)
            self?.connection = nil
        }
        
        connection.interruptionHandler = { [weak self] in
            self?.logger.error("XPC connection interrupted", file: #file, function: #function, line: #line)
            self?.connection = nil
        }
        
        // Resume the connection
        connection.resume()
        self.connection = connection
        
        logger.info("XPC connection established", file: #file, function: #function, line: #line)
    }
    
    /// Get proxy object for remote calls
    private func getProxy() throws -> ResticXPCServiceProtocol {
        try ensureConnection()
        
        guard let proxy = connection?.remoteObjectProxy as? ResticXPCServiceProtocol else {
            logger.error("Failed to get XPC proxy", file: #file, function: #function, line: #line)
            throw SecurityError.xpcConnectionFailed("Failed to get proxy object")
        }
        
        return proxy
    }
}

// MARK: - ResticXPCServiceProtocol Implementation

extension ResticXPCService: ResticXPCServiceProtocol {
    public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ResticXPCService else { return false }
        return serviceName == other.serviceName
    }
    
    public var hash: Int {
        return serviceName.hash
    }
    
    public var superclass: AnyClass? {
        return NSObject.self
    }
    
    public func `self`() -> Self {
        return self
    }
    
    public func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! {
        return nil
    }
    
    public func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! {
        return nil
    }
    
    public func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! {
        return nil
    }
    
    public func isProxy() -> Bool {
        return false
    }
    
    public func isKind(of aClass: AnyClass) -> Bool {
        return self.isKind(of: aClass)
    }
    
    public func isMember(of aClass: AnyClass) -> Bool {
        return type(of: self) == aClass
    }
    
    public func conforms(to aProtocol: Protocol) -> Bool {
        return self.conforms(to: aProtocol)
    }
    
    public func responds(to aSelector: Selector!) -> Bool {
        return self.responds(to: aSelector)
    }
    
    public var description: String {
        return "ResticXPCService(serviceName: \(serviceName))"
    }
    
    public func connect() async throws {
        logger.debug("Connecting to XPC service", file: #file, function: #function, line: #line)
        
        do {
            try ensureConnection()
            let proxy = try getProxy()
            try await proxy.connect()
            logger.info("Connected to XPC service", file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to connect: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.xpcConnectionFailed("Failed to connect: \(error.localizedDescription)")
        }
    }
    
    public func executeCommand(_ command: String, withBookmark bookmark: Data?) async throws -> ProcessResult {
        logger.debug("Executing command through XPC", file: #file, function: #function, line: #line)
        
        do {
            let proxy = try getProxy()
            let result = try await proxy.executeCommand(command, withBookmark: bookmark)
            logger.info("Command executed successfully", file: #file, function: #function, line: #line)
            return result
        } catch {
            logger.error("Command execution failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.xpcServiceError("Command execution failed: \(error.localizedDescription)")
        }
    }
    
    public func startAccessing(_ url: URL) -> Bool {
        logger.debug("Starting resource access through XPC", file: #file, function: #function, line: #line)
        
        do {
            let proxy = try getProxy()
            let success = proxy.startAccessing(url)
            logger.info("Resource access \(success ? "started" : "failed")", file: #file, function: #function, line: #line)
            return success
        } catch {
            logger.error("Failed to start access: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            return false
        }
    }
    
    public func stopAccessing(_ url: URL) {
        logger.debug("Stopping resource access through XPC", file: #file, function: #function, line: #line)
        
        do {
            let proxy = try getProxy()
            proxy.stopAccessing(url)
            logger.info("Resource access stopped", file: #file, function: #function, line: #line)
        } catch {
            logger.error("Failed to stop access: \(error.localizedDescription)", file: #file, function: #function, line: #line)
        }
    }
    
    public func validatePermissions() async throws -> Bool {
        logger.debug("Validating XPC permissions", file: #file, function: #function, line: #line)
        
        do {
            let proxy = try getProxy()
            let isValid = try await proxy.validatePermissions()
            logger.info("Permission validation \(isValid ? "succeeded" : "failed")", file: #file, function: #function, line: #line)
            return isValid
        } catch {
            logger.error("Permission validation failed: \(error.localizedDescription)", file: #file, function: #function, line: #line)
            throw SecurityError.xpcValidationFailed("Permission validation failed: \(error.localizedDescription)")
        }
    }
}
