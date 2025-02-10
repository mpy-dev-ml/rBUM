import Foundation

/// Protocol for services that require sandbox compliance
public protocol SandboxedService: SandboxCompliant {
    /// The security service used for sandbox operations
    var securityService: SecurityServiceProtocol { get }
}
