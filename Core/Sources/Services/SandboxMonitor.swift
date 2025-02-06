//
//  SandboxMonitor.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import Foundation
import AppKit

/// Service for monitoring sandbox compliance and resource access
public final class SandboxMonitor: BaseSandboxedService {
    // MARK: - Properties
    private let monitorQueue: DispatchQueue
    private var activeResources: Set<URL> = []
    private let maxResourceAccessDuration: TimeInterval
    
    public weak var delegate: SandboxMonitorDelegate?
    
    public var isHealthy: Bool {
        // For now, just check if we're able to monitor
        !activeResources.isEmpty
    }
    
    // MARK: - Initialization
    public init(logger: LoggerProtocol, securityService: SecurityServiceProtocol, maxResourceAccessDuration: TimeInterval = 3600) {
        self.monitorQueue = DispatchQueue(label: "dev.mpy.rBUM.sandbox.monitor", attributes: .concurrent)
        self.maxResourceAccessDuration = maxResourceAccessDuration
        super.init(logger: logger, securityService: securityService)
        setupNotifications()
    }
}

// MARK: - SandboxMonitorProtocol Implementation
extension SandboxMonitor: SandboxMonitorProtocol {
    public var isMonitoring: Bool {
        <#code#>
    }
    
    public func startMonitoring(url: URL) -> Bool {
        monitorQueue.sync(flags: .barrier) {
            guard !activeResources.contains(url) else { return true }
            
            Task {
                do {
                    if try await startAccessing(url) {
                        activeResources.insert(url)
                        delegate?.sandboxMonitor(self, didReceive: .accessGranted, for: url)
                        return true
                    } else {
                        delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
                        return false
                    }
                } catch {
                    logger.error("Failed to start monitoring: \(error.localizedDescription)",
                               file: #file,
                               function: #function,
                               line: #line)
                    delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
                    return false
                }
            }
            return false
        }
    }
    
    public func stopMonitoring(for url: URL) {
        monitorQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.activeResources.contains(url) {
                self.activeResources.remove(url)
                self.delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
            }
        }
    }
    
    public func isMonitoring(url: URL) -> Bool {
        monitorQueue.sync {
            activeResources.contains(url)
        }
    }
}

// MARK: - Private Methods
private extension SandboxMonitor {
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResourceAccessChange(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleResourceAccessChange(_:)),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc func handleResourceAccessChange(_ notification: Notification) {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            
            Task {
                for url in self.activeResources {
                    do {
                        if try await self.startAccessing(url) {
                            self.delegate?.sandboxMonitor(self, didReceive: .accessGranted, for: url)
                        } else {
                            self.activeResources.remove(url)
                            self.delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
                        }
                    } catch {
                        self.logger.error("Failed to access resource: \(error.localizedDescription)",
                                        file: #file,
                                        function: #function,
                                        line: #line)
                        self.activeResources.remove(url)
                        self.delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
                    }
                }
            }
        }
    }
}
