import Foundation
import os.log

/// Tracks metrics for security operations
@available(macOS 13.0, *)
@objc public final class SecurityMetrics: NSObject {
    private let logger: Logger
    private let queue = DispatchQueue(label: "dev.mpy.rbum.security.metrics")

    // Access metrics
    @objc private(set) var activeAccessCount: Int = 0
    @objc private(set) var totalAccessCount: Int = 0
    @objc private(set) var accessFailures: Int = 0

    // Bookmark metrics
    @objc private(set) var totalBookmarks: Int = 0
    @objc private(set) var bookmarkFailures: Int = 0

    // Permission metrics
    @objc private(set) var totalPermissions: Int = 0
    @objc private(set) var permissionFailures: Int = 0

    @objc override public init() {
        logger = Logger(subsystem: "dev.mpy.rbum", category: "SecurityMetrics")
        super.init()
    }

    @objc public init(logger: Logger) {
        self.logger = logger
        super.init()
    }

    @objc public func recordAccess(success: Bool = true, error: String? = nil) {
        queue.sync {
            if success {
                activeAccessCount += 1
                totalAccessCount += 1
            } else {
                accessFailures += 1
                if let error {
                    logger.error("Access failure: \(error)")
                }
            }
        }
    }

    @objc public func recordAccessEnd() {
        queue.sync {
            activeAccessCount = max(0, activeAccessCount - 1)
        }
    }

    @objc public func recordBookmark(success: Bool = true, error: String? = nil) {
        queue.sync {
            if success {
                totalBookmarks += 1
            } else {
                bookmarkFailures += 1
                if let error {
                    logger.error("Bookmark failure: \(error)")
                }
            }
        }
    }

    @objc public func recordPermission(success: Bool = true, error: String? = nil) {
        queue.sync {
            if success {
                totalPermissions += 1
            } else {
                permissionFailures += 1
                if let error {
                    logger.error("Permission failure: \(error)")
                }
            }
        }
    }
}
