//
//  SandboxedService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation

/// Protocol for services that require sandbox compliance
public protocol SandboxedService: SandboxCompliant {
    /// The security service used for sandbox operations
    var securityService: SecurityServiceProtocol { get }
}
