import Foundation

/// Represents the result of a Restic command execution
@objc public class ResticCommandResult: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }

    public let output: String
    public let error: String
    public let exitCode: Int32

    public init(output: String, error: String, exitCode: Int32) {
        self.output = output
        self.error = error
        self.exitCode = exitCode
        super.init()
    }

    public func encode(with coder: NSCoder) {
        coder.encode(output, forKey: "output")
        coder.encode(error, forKey: "error")
        coder.encode(exitCode, forKey: "exitCode")
    }

    public required init?(coder: NSCoder) {
        output = coder.decodeObject(of: NSString.self, forKey: "output") as? String ?? ""
        error = coder.decodeObject(of: NSString.self, forKey: "error") as? String ?? ""
        exitCode = coder.decodeInt32(forKey: "exitCode")
        super.init()
    }
}

/// The protocol that defines the XPC service API for executing Restic commands
@objc public protocol ResticServiceProtocol {
    /// Initialises a new repository at the specified location
    /// - Parameters:
    ///   - repositoryURL: Security-scoped bookmark data for the repository location
    ///   - password: Repository password (will be securely handled)
    ///   - reply: Completion handler with the command result
    func initialiseRepository(
        at repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    )

    /// Creates a new backup snapshot
    /// - Parameters:
    ///   - repositoryURL: Security-scoped bookmark data for the repository
    ///   - sourcePaths: Array of security-scoped bookmark data for source paths
    ///   - password: Repository password
    ///   - excludePatterns: Array of patterns to exclude
    ///   - reply: Completion handler with the command result
    func createBackup(
        repository repositoryURL: Data,
        sourcePaths: [Data],
        password: String,
        excludePatterns: [String],
        with reply: @escaping (ResticCommandResult) -> Void
    )

    /// Lists snapshots in the repository
    /// - Parameters:
    ///   - repositoryURL: Security-scoped bookmark data for the repository
    ///   - password: Repository password
    ///   - reply: Completion handler with the command result
    func listSnapshots(
        repository repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    )

    /// Restores files from a snapshot
    /// - Parameters:
    ///   - repositoryURL: Security-scoped bookmark data for the repository
    ///   - targetPath: Security-scoped bookmark data for the restore target
    ///   - snapshotID: ID of the snapshot to restore from
    ///   - password: Repository password
    ///   - paths: Optional specific paths to restore (nil for entire snapshot)
    ///   - reply: Completion handler with the command result
    func restore(
        repository repositoryURL: Data,
        to targetPath: Data,
        snapshot snapshotID: String,
        password: String,
        paths: [String]?,
        with reply: @escaping (ResticCommandResult) -> Void
    )

    /// Verifies repository integrity
    /// - Parameters:
    ///   - repositoryURL: Security-scoped bookmark data for the repository
    ///   - password: Repository password
    ///   - reply: Completion handler with the command result
    func verifyRepository(
        at repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    )

    /// Cancels any running Restic operation
    /// - Parameter reply: Completion handler indicating if cancel was successful
    func cancelOperation(with reply: @escaping (Bool) -> Void)

    /// Validates that a security-scoped bookmark is still valid
    /// - Parameters:
    ///   - bookmarkData: The bookmark data to validate
    ///   - reply: Completion handler with validation result and any error
    func validateBookmark(_ bookmarkData: Data, with reply: @escaping (Bool, Error?) -> Void)
}

/*
 To use the service from the main application:

     let connection = NSXPCConnection(serviceName: "dev.mpy.ResticService")
     connection.remoteObjectInterface = NSXPCInterface(with: ResticServiceProtocol.self)
     connection.resume()

     if let proxy = connection.remoteObjectProxy as? ResticServiceProtocol {
         // Create security-scoped bookmarks for file access
         let repoBookmark = try fileManager.bookmarkData(for: repoURL)

         proxy.initialiseRepository(at: repoBookmark, password: "secure-password") { result in
             if result.exitCode == 0 {
                 print("Repository initialised successfully")
             } else {
                 print("Error: \(result.error)")
             }
         }
     }

     // Always clean up when finished
     connection.invalidate()
 */
