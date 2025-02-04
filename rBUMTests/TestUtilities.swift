import XCTest
@testable import rBUM
@testable import Core

// MARK: - Mock Logger
class MockLogger: LoggerProtocol {
    var messages: [String] = []
    var metadata: [[String: LogMetadataValue]] = []
    var privacyLevels: [LogPrivacy] = []
    
    func debug(_ message: String, metadata: [String: LogMetadataValue]? = nil, privacy: LogPrivacy = .public, file: String = #file, function: String = #function, line: Int = #line) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        self.privacyLevels.append(privacy)
    }
    
    func info(_ message: String, metadata: [String: LogMetadataValue]? = nil, privacy: LogPrivacy = .public, file: String = #file, function: String = #function, line: Int = #line) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        self.privacyLevels.append(privacy)
    }
    
    func warning(_ message: String, metadata: [String: LogMetadataValue]? = nil, privacy: LogPrivacy = .public, file: String = #file, function: String = #function, line: Int = #line) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        self.privacyLevels.append(privacy)
    }
    
    func error(_ message: String, metadata: [String: LogMetadataValue]? = nil, privacy: LogPrivacy = .public, file: String = #file, function: String = #function, line: Int = #line) {
        messages.append(message)
        self.metadata.append(metadata ?? [:])
        self.privacyLevels.append(privacy)
    }
    
    func containsMessage(_ pattern: String) -> Bool {
        return messages.contains { $0.contains(pattern) }
    }
    
    func clear() {
        messages.removeAll()
        metadata.removeAll()
        privacyLevels.removeAll()
    }
}

// MARK: - Mock Security Service
class MockSecurityService: SecurityServiceProtocol {
    var isHealthy: Bool = true
    var hasAccess: Bool = true
    var shouldFailValidation: Bool = false
    var validatedURLs: [URL] = []
    var requestedURLs: [URL] = []
    var revokedURLs: [URL] = []
    
    func validateAccess(to url: URL) async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.accessDenied
        }
        validatedURLs.append(url)
        return hasAccess
    }
    
    func requestAccess(to url: URL) async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.accessDenied
        }
        requestedURLs.append(url)
        return hasAccess
    }
    
    func revokeAccess(to url: URL) {
        revokedURLs.append(url)
    }
    
    func validateEncryption() async throws -> Bool {
        if shouldFailValidation {
            throw SecurityError.encryptionFailed
        }
        return true
    }
    
    func performHealthCheck() async -> Bool {
        return isHealthy
    }
    
    func clear() {
        validatedURLs.removeAll()
        requestedURLs.removeAll()
        revokedURLs.removeAll()
        isHealthy = true
        hasAccess = true
        shouldFailValidation = false
    }
}

// MARK: - Mock XPC Service
class MockXPCService: ResticXPCServiceProtocol {
    var isHealthy: Bool = true
    var isConnected: Bool = true
    var shouldFailConnection: Bool = false
    var operations: [(Date, String)] = []
    var initializedRepository: String?
    var backedUpSource: String?
    var backedUpRepository: String?
    var listedRepository: String?
    var restoredRepository: String?
    var restoredSnapshot: String?
    var restoredDestination: String?
    var verifiedRepository: String?
    var usedPassword: String?
    var snapshotsToReturn: [Snapshot] = []
    
    func initializeRepository(at path: String, password: String) async throws {
        if shouldFailConnection {
            throw XPCError.connectionFailed
        }
        operations.append((Date(), "initialize"))
        initializedRepository = path
        usedPassword = password
    }
    
    func backup(source: String, to repository: String, password: String) async throws {
        if shouldFailConnection {
            throw XPCError.connectionFailed
        }
        operations.append((Date(), "backup"))
        backedUpSource = source
        backedUpRepository = repository
        usedPassword = password
    }
    
    func listSnapshots(in repository: String, password: String) async throws -> [Snapshot] {
        if shouldFailConnection {
            throw XPCError.connectionFailed
        }
        operations.append((Date(), "list"))
        listedRepository = repository
        usedPassword = password
        return snapshotsToReturn
    }
    
    func restore(from repository: String, snapshot: String, to destination: String, password: String) async throws {
        if shouldFailConnection {
            throw XPCError.connectionFailed
        }
        operations.append((Date(), "restore"))
        restoredRepository = repository
        restoredSnapshot = snapshot
        restoredDestination = destination
        usedPassword = password
    }
    
    func verify(repository: String, password: String) async throws {
        if shouldFailConnection {
            throw XPCError.connectionFailed
        }
        operations.append((Date(), "verify"))
        verifiedRepository = repository
        usedPassword = password
    }
    
    func performHealthCheck() async -> Bool {
        return isHealthy && isConnected
    }
    
    func clear() {
        operations.removeAll()
        initializedRepository = nil
        backedUpSource = nil
        backedUpRepository = nil
        listedRepository = nil
        restoredRepository = nil
        restoredSnapshot = nil
        restoredDestination = nil
        verifiedRepository = nil
        usedPassword = nil
        snapshotsToReturn.removeAll()
        isHealthy = true
        isConnected = true
        shouldFailConnection = false
    }
}

// MARK: - Mock Keychain Service
class MockKeychainService: KeychainServiceProtocol {
    var isHealthy: Bool = true
    var storedCredentials: KeychainCredentials?
    var credentialsToReturn: KeychainCredentials?
    var bookmarkToReturn: Data?
    var dataToReturn: Data?
    var storedBookmarks: [URL: Data] = [:]
    var storedPasswords: [String: [String: Data]] = [:]
    
    func storeCredentials(_ credentials: KeychainCredentials) throws {
        storedCredentials = credentials
    }
    
    func retrieveCredentials() throws -> KeychainCredentials {
        guard let credentials = credentialsToReturn else {
            throw KeychainError.itemNotFound
        }
        return credentials
    }
    
    func deleteCredentials() throws {
        storedCredentials = nil
        credentialsToReturn = nil
    }
    
    func storeBookmark(_ bookmark: Data, for url: URL) throws {
        storedBookmarks[url] = bookmark
    }
    
    func retrieveBookmark(for url: URL) throws -> Data {
        if let bookmark = storedBookmarks[url] {
            return bookmark
        }
        return bookmarkToReturn ?? Data()
    }
    
    func deleteBookmark(for url: URL) throws {
        storedBookmarks.removeValue(forKey: url)
    }
    
    func storeGenericPassword(_ password: Data, service: String, account: String) throws {
        if storedPasswords[service] == nil {
            storedPasswords[service] = [:]
        }
        storedPasswords[service]?[account] = password
    }
    
    func retrieveGenericPassword(service: String, account: String) throws -> Data {
        if let password = storedPasswords[service]?[account] {
            return password
        }
        guard let data = dataToReturn else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func deleteGenericPassword(service: String, account: String) throws {
        storedPasswords[service]?.removeValue(forKey: account)
    }
    
    func performHealthCheck() async -> Bool {
        return isHealthy
    }
    
    func clear() {
        storedCredentials = nil
        credentialsToReturn = nil
        bookmarkToReturn = nil
        dataToReturn = nil
        storedBookmarks.removeAll()
        storedPasswords.removeAll()
        isHealthy = true
    }
}

// MARK: - Mock Bookmark Service
class MockBookmarkService: BookmarkServiceProtocol {
    var isHealthy: Bool = true
    var isValidBookmark: Bool = false
    var bookmarkedURL: URL?
    var bookmarkToReturn: Data?
    var canStartAccessing: Bool = false
    var stoppedURL: URL?
    var accessedURLs: Set<URL> = []
    
    func createBookmark(for url: URL, readOnly: Bool) async throws -> Data {
        bookmarkedURL = url
        return bookmarkToReturn ?? Data()
    }
    
    func resolveBookmark(_ bookmark: Data) async throws -> URL {
        guard let url = bookmarkedURL else {
            throw BookmarkError.resolutionFailed("No URL")
        }
        return url
    }
    
    func startAccessing(_ url: URL) async throws -> Bool {
        if canStartAccessing {
            accessedURLs.insert(url)
        }
        return canStartAccessing
    }
    
    func stopAccessing(_ url: URL) {
        stoppedURL = url
        accessedURLs.remove(url)
    }
    
    func validateBookmark(for url: URL) async throws -> Bool {
        return isValidBookmark
    }
    
    func performHealthCheck() async -> Bool {
        return isHealthy
    }
    
    func clear() {
        bookmarkedURL = nil
        bookmarkToReturn = nil
        stoppedURL = nil
        accessedURLs.removeAll()
        isHealthy = true
        isValidBookmark = false
        canStartAccessing = false
    }
}

// MARK: - Mock Sandbox Monitor
class MockSandboxMonitor: SandboxMonitorProtocol {
    var isHealthy: Bool = true
    var trackedURL: URL?
    var stoppedURL: URL?
    var trackedResources: Set<URL> = []
    
    func trackResourceAccess(to url: URL) {
        trackedURL = url
        trackedResources.insert(url)
    }
    
    func stopTrackingResource(_ url: URL) {
        stoppedURL = url
        trackedResources.remove(url)
    }
    
    func checkResourceAccess(to url: URL) -> Bool {
        return trackedResources.contains(url)
    }
    
    func performHealthCheck() async -> Bool {
        return isHealthy
    }
    
    func clear() {
        trackedURL = nil
        stoppedURL = nil
        trackedResources.removeAll()
        isHealthy = true
    }
}

// MARK: - Test Helpers
extension XCTestCase {
    func createTemporaryFile(name: String = UUID().uuidString, content: String = "test") throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    func cleanupTemporaryFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    func createTemporaryDirectory(name: String = UUID().uuidString) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
        return tempURL
    }
    
    func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
