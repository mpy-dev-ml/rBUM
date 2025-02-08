//
//  TestSecurityUtilities.swift
//  rBUM
//
//  First created: 8 February 2025
//  Last updated: 8 February 2025
//

import Core
import Foundation

/// Utilities for testing security-related functionality
enum TestSecurityUtilities {
    /// Creates a test keychain item with the specified attributes
    static func createTestKeychainItem(
        id: String,
        data: Data,
        accessGroup: String? = nil
    ) throws -> KeychainItem {
        var attributes: [String: Any] = [
            kSecAttrAccount as String: id,
            kSecValueData as String: data,
            kSecClass as String: kSecClassGenericPassword
        ]
        
        if let accessGroup = accessGroup {
            attributes[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return KeychainItem(attributes: attributes)
    }
    
    /// Creates a test bookmark for the specified URL
    static func createTestBookmark(for url: URL) throws -> Data {
        return try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
    
    /// Validates access to a URL using security-scoped bookmarks
    static func validateURLAccess(_ url: URL) throws -> Bool {
        var isStale = false
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        guard let resolvedURL = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }
        
        return !isStale && resolvedURL == url
    }
}
