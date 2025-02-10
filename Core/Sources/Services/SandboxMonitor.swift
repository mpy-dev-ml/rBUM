import AppKit
import Foundation

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

    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        maxResourceAccessDuration: TimeInterval = 3600
    ) {
        monitorQueue = DispatchQueue(label: "dev.mpy.rBUM.sandbox.monitor", attributes: .concurrent)
        self.maxResourceAccessDuration = maxResourceAccessDuration
        super.init(logger: logger, securityService: securityService)
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleApplicationWillTerminate() {
        // Clean up all monitored resources
        let resources = monitorQueue.sync { Array(activeResources) }
        resources.forEach { stopMonitoring(for: $0) }
    }
}

// MARK: - SandboxMonitorProtocol Implementation

extension SandboxMonitor: SandboxMonitorProtocol {
    public var isMonitoring: Bool {
        get {
            monitorQueue.sync {
                !activeResources.isEmpty
            }
        }
        set {
            logger.warning(
                "Attempted to set isMonitoring to \(newValue), but this property is read-only",
                file: #file,
                function: #function,
                line: #line
            )
        }
    }

    public func startMonitoring(url: URL) -> Bool {
        monitorQueue.sync(flags: .barrier) {
            guard !activeResources.contains(url) else { return true }

            Task {
                do {
                    if try await startAccessing(url) {
                        activeResources.insert(url)
                        delegate?.sandboxMonitor(self, didReceive: .accessGranted, for: url)

                        // Schedule access expiration
                        scheduleAccessExpiration(for: url)
                    }
                } catch {
                    logger.error(
                        "Failed to start monitoring: \(error.localizedDescription)",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                    delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
                }
            }
            return true
        }
    }

    public func stopMonitoring(for url: URL) {
        monitorQueue.sync(flags: .barrier) {
            guard activeResources.contains(url) else { return }

            Task {
                do {
                    try await stopAccessing(url)
                    activeResources.remove(url)
                    delegate?.sandboxMonitor(self, didReceive: .accessRevoked, for: url)
                } catch {
                    logger.error(
                        "Failed to stop monitoring: \(error.localizedDescription)",
                        file: #file,
                        function: #function,
                        line: #line
                    )
                }
            }
        }
    }

    public func isMonitoring(url: URL) -> Bool {
        monitorQueue.sync {
            activeResources.contains(url)
        }
    }

    private func scheduleAccessExpiration(for url: URL) {
        Task {
            try await Task.sleep(nanoseconds: UInt64(maxResourceAccessDuration * 1_000_000_000))
            delegate?.sandboxMonitor(self, didReceive: .accessExpired, for: url)
            stopMonitoring(for: url)
        }
    }
}
