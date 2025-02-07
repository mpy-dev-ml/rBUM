import Core
import Foundation

extension BackupViewModel {
    // MARK: - Configuration Management

    /// Add a source URL to the backup configuration
    /// - Parameter url: The URL to add as a source
    func addSource(_ url: URL) async throws {
        logger.debug("Adding source to backup: \(url.path)")

        // Check if source already exists
        guard !configuration.sources.contains(where: { $0.url == url }) else {
            throw BackupError.duplicateSource("Source already exists: \(url.path)")
        }

        // Validate access to source
        try await securityService.validateAccess(to: url)

        // Create bookmark for source
        let bookmark = try await bookmarkService.createBookmark(for: url)

        // Add source to configuration
        let source = BackupSource(url: url, bookmark: bookmark)
        configuration.sources.append(source)

        logger.info("Added source to backup configuration", metadata: [
            "source": .string(url.path),
            "total_sources": .string("\(configuration.sources.count)")
        ])
    }

    /// Remove a source URL from the backup configuration
    /// - Parameter url: The URL to remove
    func removeSource(_ url: URL) {
        configuration.sources.removeAll { $0.url == url }
        logger.info("Removed source from backup configuration", metadata: [
            "source": .string(url.path),
            "total_sources": .string("\(configuration.sources.count)")
        ])
    }

    /// Update backup settings
    /// - Parameter settings: The new settings to apply
    func updateSettings(_ settings: BackupSettings) {
        configuration.settings = settings
        logger.info("Updated backup settings", metadata: [
            "compression": .string("\(settings.compression)"),
            "encryption": .string("\(settings.encryption)")
        ])
    }

    /// Add tags to the backup configuration
    /// - Parameter tags: Array of tags to add
    func addTags(_ tags: [String]) {
        let newTags = Set(tags).subtracting(configuration.tags)
        configuration.tags.append(contentsOf: newTags)
        logger.info("Added tags to backup configuration", metadata: [
            "new_tags": .string("\(newTags)"),
            "total_tags": .string("\(configuration.tags.count)")
        ])
    }

    /// Remove tags from the backup configuration
    /// - Parameter tags: Array of tags to remove
    func removeTags(_ tags: [String]) {
        configuration.tags.removeAll { tags.contains($0) }
        logger.info("Removed tags from backup configuration", metadata: [
            "removed_tags": .string("\(tags)"),
            "total_tags": .string("\(configuration.tags.count)")
        ])
    }
}
