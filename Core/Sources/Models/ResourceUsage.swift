/// Model representing resource usage metrics
struct ResourceUsage {
    /// Memory usage in bytes
    var memory: UInt64 = 0
    
    /// CPU usage percentage
    var cpu: Double = 0
    
    /// Number of open file descriptors
    var fileDescriptors: Int = 0

    /// Zero resource usage
    static let zero = ResourceUsage()
}
