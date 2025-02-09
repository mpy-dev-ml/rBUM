import Foundation

/// A mock repository discovery service for SwiftUI previews
public final class PreviewRepositoryDiscoveryService: RepositoryDiscoveryProtocol {
    public init() {}
    
    public func scanLocation(_ url: URL, recursive: Bool) async throws -> [DiscoveredRepository] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
        
        return [
            DiscoveredRepository(
                url: URL(filePath: "/Users/mpy/Backups/Photos"),
                type: .local,
                discoveredAt: Date(),
                isVerified: true,
                metadata: RepositoryMetadata(
                    size: 1024 * 1024 * 1024 * 50, // 50GB
                    lastModified: Date().addingTimeInterval(-86400 * 2), // 2 days ago
                    snapshotCount: 25
                )
            ),
            DiscoveredRepository(
                url: URL(filePath: "/Users/mpy/Backups/Documents"),
                type: .local,
                discoveredAt: Date(),
                isVerified: true,
                metadata: RepositoryMetadata(
                    size: 1024 * 1024 * 1024 * 10, // 10GB
                    lastModified: Date().addingTimeInterval(-3600), // 1 hour ago
                    snapshotCount: 12
                )
            )
        ]
    }
    
    public func verifyRepository(_ repository: DiscoveredRepository) async throws -> Bool {
        try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)
        return true
    }
    
    public func indexRepository(_ repository: DiscoveredRepository) async throws {
        try await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)
    }
    
    public func cancelDiscovery() {
        // No-op in preview
    }
}
