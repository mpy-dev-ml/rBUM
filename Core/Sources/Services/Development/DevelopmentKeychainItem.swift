import Foundation

/// Represents a keychain item with metadata
struct DevelopmentKeychainItem {
    let data: Data
    let createdAt: Date
    let lastAccessed: Date
    let accessCount: Int
    let accessGroup: String?
    let attributes: [String: Any]

    static func create(
        data: Data,
        accessGroup: String?,
        attributes: [String: Any] = [:]
    ) -> DevelopmentKeychainItem {
        let now = Date()
        return DevelopmentKeychainItem(
            data: data,
            createdAt: now,
            lastAccessed: now,
            accessCount: 0,
            accessGroup: accessGroup,
            attributes: attributes
        )
    }
}
