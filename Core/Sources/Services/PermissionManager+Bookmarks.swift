import Foundation

extension PermissionManager {
    // MARK: - Bookmark Management

    func persistBookmark(_ bookmark: Data, for url: URL) throws {
        logger.debug(
            "Persisting bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            try keychain.save(bookmark, for: url.path, accessGroup: permissionAccessGroup)
        } catch {
            logger.error(
                "Failed to persist bookmark: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw PermissionError.persistenceFailed(error.localizedDescription)
        }
    }

    func loadBookmark(for url: URL) throws -> Data? {
        logger.debug(
            "Loading bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        return try keychain.retrieve(for: url.path, accessGroup: permissionAccessGroup)
    }

    func removeBookmark(for url: URL) throws {
        logger.debug(
            "Removing bookmark for: \(url.path)",
            file: #file,
            function: #function,
            line: #line
        )

        do {
            try keychain.delete(for: url.path, accessGroup: permissionAccessGroup)
        } catch {
            logger.error(
                "Failed to remove bookmark: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            throw PermissionError.revocationFailed(error.localizedDescription)
        }
    }
}
