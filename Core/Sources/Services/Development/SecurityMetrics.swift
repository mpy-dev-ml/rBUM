import Foundation
import os.log

/// Tracks metrics for security operations
@available(macOS 13.0, *)
public final class SecurityMetrics {
    private let logger: Logger
    private let queue = DispatchQueue(label: "dev.mpy.rbum.security.metrics")
    
    // Access metrics
    private(set) var activeAccessCount: Int = 0
    private(set) var totalAccessCount: Int = 0
    private(set) var accessFailures: Int = 0
    
    // Bookmark metrics
    private(set) var totalBookmarks: Int = 0
    private(set) var bookmarkFailures: Int = 0
    
    // Permission metrics
    private(set) var totalPermissions: Int = 0
    private(set) var permissionFailures: Int = 0
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func recordAccess(success: Bool = true, error: String? = nil) {
        queue.sync {
            if success {
                activeAccessCount += 1
                totalAccessCount += 1
            } else {
                accessFailures += 1
                if let error = error {
                    logger.error("Access failure: \(error)")
                }
            }
        }
    }
    
    func recordAccessEnd() {
        queue.sync {
            activeAccessCount = max(0, activeAccessCount - 1)
        }
    }
    
    func recordBookmark(success: Bool = true, error: String? = nil) {
        queue.sync {
            if success {
                totalBookmarks += 1
            } else {
                bookmarkFailures += 1
                if let error = error {
                    logger.error("Bookmark failure: \(error)")
                }
            }
        }
    }
    
    func recordPermission(success: Bool = true, error: String? = nil) {
        queue.sync {
            if success {
                totalPermissions += 1
            } else {
                permissionFailures += 1
                if let error = error {
                    logger.error("Permission failure: \(error)")
                }
            }
        }
    }
}
