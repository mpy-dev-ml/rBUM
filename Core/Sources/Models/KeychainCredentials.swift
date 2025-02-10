//
//  KeychainCredentials.swift
//  UmbraCore
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import Security

// MARK: - KeychainCredentials

/// Represents credentials stored in the Keychain
///
/// This type encapsulates username and password pairs that can be securely
/// stored in the macOS Keychain. It supports:
/// - Secure credential storage
/// - Optional metadata attachment
/// - JSON encoding/decoding
///
/// Example usage:
/// ```swift
/// // Create credentials
/// let credentials = KeychainCredentials(
///     username: "admin",
///     password: "secret123",
///     metadata: [
///         "service": "backup",
///         "type": "restic"
///     ]
/// )
///
/// // Save to keychain
/// try credentials.save(withIdentifier: "backup-repo")
///
/// // Load from keychain
/// let loaded = try KeychainCredentials.load(
///     withIdentifier: "backup-repo"
/// )
/// ```
public struct KeychainCredentials: Codable, Hashable {
    // MARK: Lifecycle

    // MARK: - Initialization

    /// Creates new keychain credentials
    /// - Parameters:
    ///   - username: Account username
    ///   - password: Account password
    ///   - metadata: Optional metadata
    ///
    /// Example:
    /// ```swift
    /// let credentials = KeychainCredentials(
    ///     username: "admin",
    ///     password: "secret123",
    ///     metadata: [
    ///         "type": "repository",
    ///         "created": ISO8601DateFormatter()
    ///             .string(from: Date())
    ///     ]
    /// )
    /// ```
    public init(
        username: String,
        password: String,
        metadata: [String: String]? = nil
    ) {
        self.username = username
        self.password = password
        self.metadata = metadata
    }

    // MARK: Public

    /// The username or account name
    ///
    /// Used to identify the account or service these credentials
    /// are associated with.
    public let username: String

    /// The password or secret
    ///
    /// The sensitive data that should be stored securely in the
    /// Keychain. Never log or display this value.
    public let password: String

    /// Additional metadata for the credentials
    ///
    /// Optional key-value pairs that provide context about:
    /// - Associated service
    /// - Credential type
    /// - Usage information
    /// - Creation details
    public let metadata: [String: String]?
}

// MARK: - Keychain Access

public extension KeychainCredentials {
    /// Service identifier for keychain items
    private static let service = "com.rbum.credentials"

    /// Access group for shared keychain items
    private static let accessGroup = "com.rbum.shared"

    /// Save credentials to the keychain
    /// - Parameter identifier: Unique identifier for the credentials
    /// - Throws: KeychainError if saving fails
    ///
    /// This method:
    /// 1. Encodes credentials to JSON
    /// 2. Creates a keychain query
    /// 3. Adds data to keychain
    /// 4. Handles any errors
    func save(
        withIdentifier identifier: String
    ) throws {
        // Convert credentials to data
        let data = try JSONEncoder().encode(self)

        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: identifier,
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecValueData as String: data,
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(
                status: status,
                identifier: identifier
            )
        }
    }

    /// Load credentials from the keychain
    /// - Parameter identifier: Unique identifier for the credentials
    /// - Returns: KeychainCredentials if found
    /// - Throws: KeychainError if loading fails
    ///
    /// This method:
    /// 1. Creates a keychain query
    /// 2. Retrieves data from keychain
    /// 3. Decodes JSON data
    /// 4. Handles any errors
    static func load(
        withIdentifier identifier: String
    ) throws -> KeychainCredentials {
        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
        ]

        // Query keychain
        var result: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        guard status == errSecSuccess,
              let data = result as? Data
        else {
            throw KeychainError.loadFailed(
                status: status,
                identifier: identifier
            )
        }

        // Decode credentials
        return try JSONDecoder().decode(
            KeychainCredentials.self,
            from: data
        )
    }

    /// Delete credentials from the keychain
    /// - Parameter identifier: Unique identifier for the credentials
    /// - Throws: KeychainError if deletion fails
    ///
    /// This method:
    /// 1. Creates a keychain query
    /// 2. Deletes matching items
    /// 3. Handles any errors
    static func delete(
        withIdentifier identifier: String
    ) throws {
        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: identifier,
            kSecAttrAccessGroup as String: accessGroup,
        ]

        // Delete from keychain
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(
                status: status,
                identifier: identifier
            )
        }
    }
}

// MARK: - KeychainError

/// Errors that can occur during keychain operations
///
/// This enum provides specific error cases for:
/// - Save operations
/// - Load operations
/// - Delete operations
///
/// Each case includes:
/// - OSStatus code
/// - Affected identifier
/// - Error description
/// - Recovery suggestion
public enum KeychainError: LocalizedError {
    /// Failed to save credentials
    case saveFailed(status: OSStatus, identifier: String)

    /// Failed to load credentials
    case loadFailed(status: OSStatus, identifier: String)

    /// Failed to delete credentials
    case deleteFailed(status: OSStatus, identifier: String)

    // MARK: Public

    public var errorDescription: String? {
        switch self {
        case let .saveFailed(status, id):
            """
            Failed to save credentials for '\(id)' \
            (status: \(status))
            """

        case let .loadFailed(status, id):
            """
            Failed to load credentials for '\(id)' \
            (status: \(status))
            """

        case let .deleteFailed(status, id):
            """
            Failed to delete credentials for '\(id)' \
            (status: \(status))
            """
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            """
            Please ensure you have permission to access the keychain \
            and try again.
            """

        case .loadFailed:
            """
            The credentials may not exist or you may not have \
            permission to access them.
            """

        case .deleteFailed:
            """
            The credentials may not exist or you may not have \
            permission to delete them.
            """
        }
    }
}

// MARK: - KeychainCredentials + CustomStringConvertible

extension KeychainCredentials: CustomStringConvertible {
    public var description: String {
        var desc = """
        Credentials:
        Username: \(username)
        """

        if let metadata {
            desc += "\nMetadata:"
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                desc += "\n  \(key): \(value)"
            }
        }

        return desc
    }
}
