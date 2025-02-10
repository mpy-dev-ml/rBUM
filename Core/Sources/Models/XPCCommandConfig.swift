import Foundation

/// Configuration for XPC command execution
@objc public class XPCCommandConfig: NSObject, NSSecureCoding {
    /// Command to execute
    @objc public let command: String

    /// Command arguments
    @objc public let arguments: [String]

    /// Environment variables
    @objc public let environment: [String: String]

    /// Working directory
    @objc public let workingDirectory: String

    /// Security-scoped bookmarks
    @objc public let bookmarks: [String: NSData]

    /// Command timeout
    @objc public let timeout: TimeInterval

    /// Audit session identifier
    @objc public let auditSessionId: au_asid_t

    /// Initialize a new XPC command configuration
    /// - Parameters:
    ///   - command: Command to execute
    ///   - arguments: Command arguments
    ///   - environment: Environment variables
    ///   - workingDirectory: Working directory
    ///   - bookmarks: Security-scoped bookmarks
    ///   - timeout: Command timeout
    ///   - auditSessionId: Audit session identifier
    @objc public init(
        command: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        bookmarks: [String: NSData],
        timeout: TimeInterval,
        auditSessionId: au_asid_t
    ) {
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.bookmarks = bookmarks
        self.timeout = timeout
        self.auditSessionId = auditSessionId
        super.init()
    }

    // MARK: - NSSecureCoding

    public static var supportsSecureCoding: Bool { true }

    @objc public func encode(with coder: NSCoder) {
        coder.encode(command, forKey: "command")
        coder.encode(arguments, forKey: "arguments")
        coder.encode(environment, forKey: "environment")
        coder.encode(workingDirectory, forKey: "workingDirectory")
        coder.encode(bookmarks, forKey: "bookmarks")
        coder.encode(timeout, forKey: "timeout")
        coder.encode(auditSessionId, forKey: "auditSessionId")
    }

    @objc public required init?(coder: NSCoder) {
        guard let command = coder.decodeObject(of: NSString.self, forKey: "command") as String?,
              let arguments = coder.decodeObject(of: NSArray.self, forKey: "arguments") as? [String],
              let environment = coder.decodeObject(of: NSDictionary.self, forKey: "environment") as? [String: String],
              let workingDirectory = coder.decodeObject(of: NSString.self, forKey: "workingDirectory") as String?,
              let bookmarks = coder.decodeObject(of: NSDictionary.self, forKey: "bookmarks") as? [String: NSData]
        else {
            return nil
        }

        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.bookmarks = bookmarks
        timeout = coder.decodeDouble(forKey: "timeout")
        auditSessionId = au_asid_t(coder.decodeInt64(forKey: "auditSessionId"))
        super.init()
    }
}
