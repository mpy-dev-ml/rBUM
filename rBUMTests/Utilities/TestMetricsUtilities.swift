import Core
import Foundation

/// Utilities for testing performance metrics
enum TestMetricsUtilities {
    /// Measures the time taken to execute a block of code
    /// - Parameter block: The code block to measure
    /// - Returns: The time taken in seconds
    static func measureExecutionTime(
        _ block: () throws -> Void
    ) rethrows -> TimeInterval {
        let start = Date()
        try block()
        return Date().timeIntervalSince(start)
    }

    /// Measures the memory usage of a block of code
    /// - Parameter block: The code block to measure
    /// - Returns: The memory usage in bytes
    static func measureMemoryUsage(
        _ block: () throws -> Void
    ) rethrows -> Int64 {
        // Get initial memory usage
        let initialUsage = getMemoryUsage()

        // Execute the block
        try block()

        // Get final memory usage
        let finalUsage = getMemoryUsage()

        return finalUsage - initialUsage
    }

    /// Gets the current memory usage in bytes
    private static func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard kerr == KERN_SUCCESS else {
            return 0
        }

        return Int64(info.resident_size)
    }

    /// Measures the CPU usage of a block of code
    /// - Parameter block: The code block to measure
    /// - Returns: The CPU usage percentage
    static func measureCPUUsage(
        _ block: () throws -> Void
    ) rethrows -> Double {
        // Get initial CPU time
        let initialCPU = getCPUTime()

        // Execute the block
        try block()

        // Get final CPU time
        let finalCPU = getCPUTime()

        // Calculate CPU usage percentage
        let cpuDiff = finalCPU.total - initialCPU.total
        let timeDiff = Date().timeIntervalSince1970 - initialCPU.timeStamp

        return (cpuDiff / timeDiff) * 100.0
    }

    /// Gets the current CPU time
    private static func getCPUTime() -> (timeStamp: TimeInterval, total: Double) {
        var totalTime: Double = 0
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS else {
            return (Date().timeIntervalSince1970, 0)
        }

        for index in 0 ..< Int(threadCount) {
            var threadInfo = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)

            let kerr = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(
                        threadList![index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        $0,
                        &count
                    )
                }
            }

            guard kerr == KERN_SUCCESS else { continue }

            let userTime = Double(threadInfo.user_time.seconds) +
                Double(threadInfo.user_time.microseconds) / 1_000_000.0
            let systemTime = Double(threadInfo.system_time.seconds) +
                Double(threadInfo.system_time.microseconds) / 1_000_000.0

            totalTime += userTime + systemTime
        }

        vm_deallocate(
            mach_task_self_,
            vm_address_t(UInt(bitPattern: threadList)),
            vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
        )

        return (
            Date().timeIntervalSince1970,
            totalTime
        )
    }
}
