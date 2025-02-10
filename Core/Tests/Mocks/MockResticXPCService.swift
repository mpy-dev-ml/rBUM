import Foundation

/// A mock XPC service used for testing and initialization to break circular dependencies
public final class MockResticXPCService: NSObject, ResticXPCServiceProtocol {
    public var isHealthy: Bool = true
    public var isConnected: Bool = true
    public var shouldFailConnection: Bool = false
    public private(set) var operations: [(Date, String)] = []
    public private(set) var initializedRepository: URL?
    public private(set) var backedUpSource: URL?
    public private(set) var backedUpDestination: URL?
    public private(set) var listedRepository: URL?
    public private(set) var restoredSource: URL?
    public private(set) var restoredSnapshot: String?
    public private(set) var restoredDestination: URL?
    public private(set) var verifiedRepository: URL?
    public private(set) var usedUsername: String?
    public private(set) var usedPassword: String?
    public var snapshotsToReturn: [String] = []

    override public init() {
        super.init()
    }

    public func ping() async -> Bool {
        isHealthy && isConnected
    }

    public func initializeRepository(at url: URL, username: String, password: String) async throws {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        operations.append((Date(), "initialize"))
        initializedRepository = url
        usedUsername = username
        usedPassword = password
    }

    public func backup(from source: URL, to destination: URL, username: String, password: String) async throws {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        operations.append((Date(), "backup"))
        backedUpSource = source
        backedUpDestination = destination
        usedUsername = username
        usedPassword = password
    }

    public func listSnapshots(username: String, password: String) async throws -> [String] {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        operations.append((Date(), "list"))
        usedUsername = username
        usedPassword = password
        return snapshotsToReturn
    }

    public func restore(
        from source: URL,
        snapshot: String,
        to destination: URL,
        username: String,
        password: String
    ) async throws {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        operations.append((Date(), "restore"))
        restoredSource = source
        restoredSnapshot = snapshot
        restoredDestination = destination
        usedUsername = username
        usedPassword = password
    }

    public func verify(repository: URL, username: String, password: String) async throws {
        if shouldFailConnection {
            throw ResticXPCError.connectionFailed
        }
        operations.append((Date(), "verify"))
        verifiedRepository = repository
        usedUsername = username
        usedPassword = password
    }

    public func clear() {
        operations.removeAll()
        initializedRepository = nil
        backedUpSource = nil
        backedUpDestination = nil
        listedRepository = nil
        restoredSource = nil
        restoredSnapshot = nil
        restoredDestination = nil
        verifiedRepository = nil
        usedUsername = nil
        usedPassword = nil
        snapshotsToReturn.removeAll()
        isHealthy = true
        isConnected = true
        shouldFailConnection = false
    }
}
