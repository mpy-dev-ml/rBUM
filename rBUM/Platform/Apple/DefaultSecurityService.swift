//
//  DefaultSecurityService.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 04/02/2025.
//

import AppKit
import Core
import Foundation
import Security

/// A macOS-specific implementation of the security service that handles sandbox compliance
/// and resource access management.
///
/// `DefaultSecurityService` provides a comprehensive implementation of `SecurityServiceProtocol`
/// specifically designed for macOS. It handles:
///
/// 1. Sandbox Compliance:
///    - Security-scoped bookmark management
///    - Resource access tracking
///    - Permission management
///    - Access scope validation
///
/// 2. Resource Management:
///    - Concurrent operation handling
///    - Resource cleanup
///    - Access queue management
///    - Operation tracking
///
/// 3. Security Features:
///    - Keychain integration
///    - Sandbox monitoring
///    - Access control
///    - Error handling
///
/// Example usage:
/// ```swift
/// let securityService = DefaultSecurityService(
///     logger: logger,
///     securityService: securityService,
///     bookmarkService: bookmarkService,
///     keychainService: keychainService,
///     sandboxMonitor: sandboxMonitor
/// )
///
/// // Request permission for a file
/// try await securityService.requestPermission(for: fileURL)
///
/// // Create a persistent bookmark
/// let bookmark = try securityService.createBookmark(for: fileURL)
/// ```
public class DefaultSecurityService: BaseSandboxedService, Measurable {
    // MARK: - Properties

    /// Service responsible for managing security-scoped bookmarks
    private let bookmarkService: BookmarkServiceProtocol

    /// Service responsible for secure credential storage
    private let keychainService: KeychainServiceProtocol

    /// Service responsible for monitoring sandbox compliance
    private let sandboxMonitor: SandboxMonitorProtocol

    /// Queue for managing security operations
    private let operationQueue: OperationQueue

    /// Concurrent queue for managing access to shared resources
    private let accessQueue = DispatchQueue(label: "dev.mpy.rBUM.defaultSecurity", attributes: .concurrent)

    /// Set of currently active operation IDs
    private var activeOperations: Set<UUID> = []

    /// Indicates whether the service is currently in a healthy state.
    ///
    /// The service is considered healthy when:
    /// - No operations are stuck
    /// - All resources are properly released
    /// - No access violations are detected
    public var isHealthy: Bool {
        // Check if we have any stuck operations
        accessQueue.sync {
            self.activeOperations.isEmpty
        }
    }

    // MARK: - Initialization

    /// Initializes a new DefaultSecurityService with the required dependencies.
    ///
    /// - Parameters:
    ///   - logger: The logger for recording security events
    ///   - securityService: The underlying security service implementation
    ///   - bookmarkService: The service for managing security-scoped bookmarks
    ///   - keychainService: The service for secure credential storage
    ///   - sandboxMonitor: The service for monitoring sandbox compliance
    public init(
        logger: LoggerProtocol,
        securityService: SecurityServiceProtocol,
        bookmarkService: BookmarkServiceProtocol,
        keychainService: KeychainServiceProtocol,
        sandboxMonitor: SandboxMonitorProtocol
    ) {
        self.bookmarkService = bookmarkService
        self.keychainService = keychainService
        self.sandboxMonitor = sandboxMonitor

        operationQueue = OperationQueue()
        operationQueue.name = "dev.mpy.rBUM.defaultSecurityQueue"
        operationQueue.maxConcurrentOperationCount = 1

        super.init(logger: logger, securityService: securityService)
    }

    // MARK: - SecurityServiceProtocol Implementation

    /// Requests permission for the specified URL.
    ///
    /// This method will prompt the user to grant access to the specified URL.
    ///
    /// - Parameter url: The URL for which permission is being requested
    /// - Returns: `true` if permission is granted, `false` otherwise
    public func requestPermission(for url: URL) async throws -> Bool {
        try await measure("Request Permission") {
            // First check if we already have access
            if try await validateAccess(to: url) {
                return true
            }

            // Show open panel to request access
            let panel = await NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.directoryURL = url
            panel.message = "Please grant access to this location"
            panel.prompt = "Grant Access"

            let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
            return response == .OK
        }
    }

    /// Creates a persistent bookmark for the specified URL.
    ///
    /// - Parameter url: The URL for which a bookmark is being created
    /// - Returns: The created bookmark data
    public func createBookmark(for url: URL) throws -> Data {
        try bookmarkService.createBookmark(for: url)
    }

    /// Resolves a bookmark to its corresponding URL.
    ///
    /// - Parameter bookmark: The bookmark data to resolve
    /// - Returns: The resolved URL
    public func resolveBookmark(_ bookmark: Data) throws -> URL {
        try bookmarkService.resolveBookmark(bookmark)
    }

    /// Validates access to the specified URL.
    ///
    /// This method checks if the service has permission to access the specified URL.
    ///
    /// - Parameter url: The URL for which access is being validated
    /// - Returns: `true` if access is valid, `false` otherwise
    public func validateAccess(to url: URL) async throws -> Bool {
        try await measure("Validate Access") {
            do {
                let bookmark = try bookmarkService.createBookmark(for: url)
                return try bookmarkService.validateBookmark(bookmark)
            } catch {
                logger.error(
                    "Failed to validate access: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }

    /// Starts accessing the specified URL.
    ///
    /// This method will attempt to start accessing the specified URL.
    ///
    /// - Parameter url: The URL for which access is being started
    /// - Returns: `true` if access is started successfully, `false` otherwise
    override public func startAccessing(_ url: URL) -> Bool {
        do {
            return try bookmarkService.startAccessing(url)
        } catch {
            logger.error(
                "Failed to start accessing: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            return false
        }
    }

    /// Stops accessing the specified URL.
    ///
    /// This method will attempt to stop accessing the specified URL.
    ///
    /// - Parameter url: The URL for which access is being stopped
    override public func stopAccessing(_ url: URL) {
        Task {
            do {
                try await bookmarkService.stopAccessing(url)
            } catch {
                logger.error(
                    "Failed to stop accessing: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
            }
        }
    }

    /// Persists access to the specified URL.
    ///
    /// This method will persist access to the specified URL.
    ///
    /// - Parameter url: The URL for which access is being persisted
    /// - Returns: The persisted bookmark data
    public func persistAccess(to url: URL) async throws -> Data {
        try await measure("Persist Access") {
            let bookmark = try bookmarkService.createBookmark(for: url)
            _ = try await sandboxMonitor.startMonitoring(url: url)
            return bookmark
        }
    }

    /// Revokes access to the specified URL.
    ///
    /// This method will revoke access to the specified URL.
    ///
    /// - Parameter url: The URL for which access is being revoked
    public func revokeAccess(to url: URL) async throws {
        try await measure("Revoke Access") {
            try await sandboxMonitor.stopMonitoring(for: url)
        }
    }

    // MARK: - HealthCheckable Implementation

    /// Performs a health check on the service.
    ///
    /// This method checks the service's health by verifying that:
    /// - No operations are stuck
    /// - All resources are properly released
    /// - No access violations are detected
    ///
    /// - Returns: `true` if the service is healthy, `false` otherwise
    public func performHealthCheck() async -> Bool {
        await measure("Security Health Check") {
            do {
                // Check sandbox monitor
                let monitorHealthy = sandboxMonitor.isHealthy

                // Check active operations
                let operationsHealthy = isHealthy

                return monitorHealthy && operationsHealthy
            } catch {
                logger.error(
                    "Health check failed: \(error.localizedDescription)",
                    file: #file,
                    function: #function,
                    line: #line
                )
                return false
            }
        }
    }

    // MARK: - Private Helpers

    private func handleSecurityOperation(
        type: SecurityOperationType,
        url: URL,
        options: SecurityOptions = []
    ) async throws -> Bool {
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(operationId, type: type, url: url)
            
            // Validate prerequisites
            try await validateSecurityPrerequisites(url: url, options: options)
            
            // Execute operation
            let result = try await executeSecurityOperation(
                type: type,
                url: url,
                options: options
            )
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
            return result
            
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    private func startSecurityOperation(
        _ id: UUID,
        type: SecurityOperationType,
        url: URL
    ) async throws {
        // Record operation start
        let operation = SecurityOperation(
            id: id,
            type: type,
            url: url,
            timestamp: Date(),
            status: .inProgress
        )
        operationRecorder.recordOperation(operation)
        
        // Log operation start
        logger.info("Starting security operation", metadata: [
            "operation": .string(id.uuidString),
            "type": .string(type.rawValue),
            "url": .string(url.path)
        ])
    }
    
    private func validateSecurityPrerequisites(
        url: URL,
        options: SecurityOptions
    ) async throws {
        // Validate URL
        try await validateURL(url)
        
        // Validate security scope
        try await validateSecurityScope(for: url)
        
        // Validate options
        try await validateSecurityOptions(options, for: url)
    }
    
    private func validateURL(_ url: URL) async throws {
        // Check if URL exists
        guard url.isFileURL else {
            throw SecurityError.invalidURL("URL must be a file URL")
        }
        
        // Check if URL is reachable
        var isReachable = false
        do {
            isReachable = try url.checkResourceIsReachable()
        } catch {
            throw SecurityError.invalidURL("URL is not reachable: \(error.localizedDescription)")
        }
        
        guard isReachable else {
            throw SecurityError.invalidURL("URL is not reachable")
        }
    }
    
    private func validateSecurityScope(for url: URL) async throws {
        // Check if URL is in sandbox
        guard url.startAccessingSecurityScopedResource() else {
            throw SecurityError.accessDenied("Cannot access security-scoped resource")
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Check if URL is in allowed directories
        guard try await isInAllowedDirectory(url) else {
            throw SecurityError.accessDenied("URL is not in an allowed directory")
        }
    }
    
    private func validateSecurityOptions(
        _ options: SecurityOptions,
        for url: URL
    ) async throws {
        // Validate read access
        if options.contains(.read) {
            guard try await validateReadAccess(to: url) else {
                throw SecurityError.accessDenied("Read access denied")
            }
        }
        
        // Validate write access
        if options.contains(.write) {
            guard try await validateWriteAccess(to: url) else {
                throw SecurityError.accessDenied("Write access denied")
            }
        }
        
        // Validate execute access
        if options.contains(.execute) {
            guard try await validateExecuteAccess(to: url) else {
                throw SecurityError.accessDenied("Execute access denied")
            }
        }
    }
    
    private func validateReadAccess(to url: URL) async throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [.isReadableKey])
        guard resourceValues.isReadable else {
            return false
        }
        
        // Check sandbox permissions
        guard try await checkSandboxPermission(.read, for: url) else {
            return false
        }
        
        return true
    }
    
    private func validateWriteAccess(to url: URL) async throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [.isWritableKey])
        guard resourceValues.isWritable else {
            return false
        }
        
        // Check sandbox permissions
        guard try await checkSandboxPermission(.write, for: url) else {
            return false
        }
        
        return true
    }
    
    private func validateExecuteAccess(to url: URL) async throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [.isExecutableKey])
        guard resourceValues.isExecutable else {
            return false
        }
        
        // Check sandbox permissions
        guard try await checkSandboxPermission(.execute, for: url) else {
            return false
        }
        
        return true
    }
    
    private func checkSandboxPermission(
        _ permission: SecurityPermission,
        for url: URL
    ) async throws -> Bool {
        // Get sandbox container
        guard let container = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return false
        }
        
        // Check if URL is in sandbox container
        if url.path.starts(with: container.path) {
            return true
        }
        
        // Check if URL has security-scoped bookmark
        return try await hasSecurityScopedBookmark(for: url, permission: permission)
    }
    
    private func hasSecurityScopedBookmark(
        for url: URL,
        permission: SecurityPermission
    ) async throws -> Bool {
        // Check if bookmark exists
        guard let bookmark = try? await bookmarkStore.getBookmark(for: url) else {
            return false
        }
        
        // Resolve bookmark
        var isStale = false
        guard let bookmarkURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return false
        }
        
        // Check if bookmark is stale
        if isStale {
            try await updateBookmark(for: url)
        }
        
        // Check if bookmark URL matches
        guard bookmarkURL == url else {
            return false
        }
        
        // Check permission
        return try await checkBookmarkPermission(permission, for: url)
    }
    
    private func updateBookmark(for url: URL) async throws {
        // Create new bookmark
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // Store new bookmark
        try await bookmarkStore.storeBookmark(bookmark, for: url)
    }
    
    private func checkBookmarkPermission(
        _ permission: SecurityPermission,
        for url: URL
    ) async throws -> Bool {
        // Start accessing resource
        guard url.startAccessingSecurityScopedResource() else {
            return false
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Check permission
        switch permission {
        case .read:
            return try url.resourceValues(forKeys: [.isReadableKey]).isReadable ?? false
        case .write:
            return try url.resourceValues(forKeys: [.isWritableKey]).isWritable ?? false
        case .execute:
            return try url.resourceValues(forKeys: [.isExecutableKey]).isExecutable ?? false
        }
    }
    
    private func isInAllowedDirectory(_ url: URL) async throws -> Bool {
        // Get allowed directories
        let allowedDirectories = try await getAllowedDirectories()
        
        // Check if URL is in allowed directory
        for directory in allowedDirectories {
            if url.path.starts(with: directory.path) {
                return true
            }
        }
        
        return false
    }
    
    private func getAllowedDirectories() async throws -> [URL] {
        // Get standard directories
        let standardDirectories: [FileManager.SearchPathDirectory] = [
            .documentDirectory,
            .cachesDirectory,
            .applicationSupportDirectory
        ]
        
        // Get URLs for standard directories
        var allowedDirectories: [URL] = []
        for directory in standardDirectories {
            if let url = try? FileManager.default.url(
                for: directory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ) {
                allowedDirectories.append(url)
            }
        }
        
        // Add additional allowed directories
        allowedDirectories.append(contentsOf: try await getAdditionalAllowedDirectories())
        
        return allowedDirectories
    }
    
    private func getAdditionalAllowedDirectories() async throws -> [URL] {
        // Get additional directories from configuration
        return try await securityConfiguration.getAllowedDirectories()
    }
    
    private func executeSecurityOperation(
        type: SecurityOperationType,
        url: URL,
        options: SecurityOptions
    ) async throws -> Bool {
        switch type {
        case .access:
            return try await executeAccessOperation(url: url, options: options)
        case .bookmark:
            return try await executeBookmarkOperation(url: url, options: options)
        case .sandbox:
            return try await executeSandboxOperation(url: url, options: options)
        }
    }
    
    private func executeAccessOperation(
        url: URL,
        options: SecurityOptions
    ) async throws -> Bool {
        // Start accessing resource
        guard url.startAccessingSecurityScopedResource() else {
            return false
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Check permissions
        return try await validateSecurityOptions(options, for: url)
    }
    
    private func executeBookmarkOperation(
        url: URL,
        options: SecurityOptions
    ) async throws -> Bool {
        // Create bookmark
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // Store bookmark
        try await bookmarkStore.storeBookmark(bookmark, for: url)
        
        return true
    }
    
    private func executeSandboxOperation(
        url: URL,
        options: SecurityOptions
    ) async throws -> Bool {
        // Check if URL is in sandbox
        guard try await isInAllowedDirectory(url) else {
            return false
        }
        
        // Check permissions
        return try await validateSecurityOptions(options, for: url)
    }
    
    private func completeSecurityOperation(
        _ id: UUID,
        success: Bool,
        error: Error? = nil
    ) async throws {
        // Update operation status
        let status: SecurityOperationStatus = success ? .completed : .failed
        operationRecorder.updateOperation(id, status: status, error: error)
        
        // Log completion
        logger.info("Completed security operation", metadata: [
            "operation": .string(id.uuidString),
            "status": .string(status.rawValue),
            "error": error.map { .string($0.localizedDescription) } ?? .string("none")
        ])
        
        // Update metrics
        if success {
            metrics.recordSuccess()
        } else {
            metrics.recordFailure()
        }
    }
    
    private func handleSecurityOperation<T>(_ operation: SecurityOperationType, for url: URL, action: () async throws -> T) async throws -> T {
        let operationId = UUID()
        
        do {
            // Start operation
            try await startSecurityOperation(operationId, type: operation, url: url)
            
            // Perform action
            let result = try await action()
            
            // Complete operation
            try await completeSecurityOperation(operationId, success: true)
            
            return result
        } catch {
            // Handle failure
            try await completeSecurityOperation(operationId, success: false, error: error)
            throw error
        }
    }
    
    private func validateAccess(to url: URL, requiring permissions: Set<SecurityPermission>) async throws -> Bool {
        // Check if URL exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw SecurityError.resourceNotFound("Resource not found at \(url.path)")
        }
        
        // Check sandbox access
        guard try await checkSandboxAccess(to: url, requiring: permissions) else {
            return false
        }
        
        // Check file system permissions
        guard try await checkFileSystemPermissions(for: url, requiring: permissions) else {
            return false
        }
        
        // Check security scoped access
        guard try await checkSecurityScopedAccess(to: url) else {
            return false
        }
        
        return true
    }
    
    private func checkSandboxAccess(to url: URL, requiring permissions: Set<SecurityPermission>) async throws -> Bool {
        // Check if URL is in sandbox
        guard url.isFileURL else {
            throw SecurityError.invalidURL("URL must be a file URL")
        }
        
        // Check sandbox container access
        if url.path.hasPrefix(sandboxContainer.path) {
            return true
        }
        
        // Check bookmark access
        if let bookmark = try? await bookmarkService.findBookmark(for: url) {
            return try await validateBookmarkAccess(bookmark, requiring: permissions)
        }
        
        return false
    }
    
    private func checkFileSystemPermissions(for url: URL, requiring permissions: Set<SecurityPermission>) async throws -> Bool {
        var hasPermissions = true
        
        if permissions.contains(.readable) {
            hasPermissions = hasPermissions && fileManager.isReadable(atPath: url.path)
        }
        
        if permissions.contains(.writable) {
            hasPermissions = hasPermissions && fileManager.isWritable(atPath: url.path)
        }
        
        if permissions.contains(.executable) {
            hasPermissions = hasPermissions && fileManager.isExecutable(atPath: url.path)
        }
        
        return hasPermissions
    }
    
    private func checkSecurityScopedAccess(to url: URL) async throws -> Bool {
        // Check if we have a security scoped bookmark
        guard let bookmark = try? await bookmarkService.findBookmark(for: url) else {
            return false
        }
        
        // Start accessing security scoped resource
        var isStale = false
        let securityScopedURL = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        guard securityScopedURL.startAccessingSecurityScopedResource() else {
            return false
        }
        
        defer {
            securityScopedURL.stopAccessingSecurityScopedResource()
        }
        
        // Check if bookmark is stale
        if isStale {
            try await updateStaleBookmark(for: url)
        }
        
        return true
    }
    
    private func updateStaleBookmark(for url: URL) async throws {
        // Create new bookmark
        let newBookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // Save updated bookmark
        try await bookmarkService.updateBookmark(newBookmark, for: url)
        
        // Log update
        logger.info("Updated stale bookmark", metadata: [
            "url": .string(url.path)
        ])
    }
    
    private func validateBookmarkAccess(_ bookmark: Data, requiring permissions: Set<SecurityPermission>) async throws -> Bool {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        guard url.startAccessingSecurityScopedResource() else {
            return false
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Check file system permissions
        return try await checkFileSystemPermissions(for: url, requiring: permissions)
    }
    
    private func validateCredentials(_ credentials: RepositoryCredentials, for url: URL) async throws {
        // Check if credentials exist
        guard !credentials.password.isEmpty else {
            throw SecurityError.invalidCredentials("Password cannot be empty")
        }
        
        // Check if we can access the repository
        guard try await validateAccess(to: url, requiring: [.readable, .writable]) else {
            throw SecurityError.accessDenied("Cannot access repository at \(url.path)")
        }
        
        // Test credentials with Restic
        try await testResticCredentials(credentials, at: url)
    }
    
    private func testResticCredentials(_ credentials: RepositoryCredentials, at url: URL) async throws {
        // Create test environment
        var environment = ProcessInfo.processInfo.environment
        environment["RESTIC_PASSWORD"] = credentials.password
        environment["RESTIC_REPOSITORY"] = url.path
        
        // Try to list snapshots (lightweight operation)
        let result = try await processExecutor.execute(
            command: "restic",
            arguments: ["snapshots", "--json"],
            environment: environment,
            at: url
        )
        
        guard result.exitCode == 0 else {
            throw SecurityError.invalidCredentials(
                "Failed to validate credentials: \(result.error)"
            )
        }
    }
    
    private func validateSecurityAccess(for url: URL) async throws -> Bool {
        // Check if URL exists
        guard fileManager.fileExists(atPath: url.path) else {
            logger.error("File does not exist", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Check file system attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType else {
            return false
        }
        
        // Verify file type
        switch type {
        case .typeDirectory:
            return try validateDirectoryAccess(at: url)
        case .typeRegular:
            return try validateFileAccess(at: url)
        default:
            logger.warning("Unsupported file type", metadata: [
                "path": .string(url.path),
                "type": .string(type.rawValue)
            ])
            return false
        }
    }
    
    private func validateDirectoryAccess(at url: URL) throws -> Bool {
        // Check directory permissions
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isReadableKey, .isWritableKey],
            options: [.skipsHiddenFiles]
        )
        
        // Verify we can access the directory contents
        return !contents.isEmpty
    }
    
    private func validateFileAccess(at url: URL) throws -> Bool {
        // Check file permissions
        let resourceValues = try url.resourceValues(forKeys: [
            .isReadableKey,
            .isWritableKey,
            .fileProtectionKey
        ])
        
        guard resourceValues.isReadable else {
            logger.error("File is not readable", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        if let protection = resourceValues.fileProtection,
           protection == .complete {
            logger.error("File is encrypted", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        return true
    }
    
    private func validateSandboxAccess(to url: URL) async throws -> Bool {
        // Check if we have a bookmark
        guard let bookmark = try? await bookmarkService.getBookmark(for: url) else {
            logger.debug("No bookmark found", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Try to resolve the bookmark
        guard let resolvedURL = try? await bookmarkService.resolveBookmark(bookmark) else {
            logger.error("Failed to resolve bookmark", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Verify the resolved URL matches
        return resolvedURL.path == url.path
    }
    
    private func validatePermissions(for url: URL) async throws -> Bool {
        // Check volume permissions
        let resourceValues = try url.resourceValues(forKeys: [
            .volumeIsReadOnlyKey,
            .volumeSupportsFileCloningKey,
            .volumeSupportsExclusiveRenamingKey
        ])
        
        if let isReadOnly = resourceValues.volumeIsReadOnly,
           isReadOnly {
            logger.error("Volume is read-only", metadata: [
                "path": .string(url.path)
            ])
            return false
        }
        
        // Log support for advanced features
        if let supportsCloning = resourceValues.volumeSupportsFileCloning {
            logger.debug("Volume cloning support", metadata: [
                "path": .string(url.path),
                "supported": .bool(supportsCloning)
            ])
        }
        
        if let supportsExclusiveRenaming = resourceValues.volumeSupportsExclusiveRenaming {
            logger.debug("Volume exclusive renaming support", metadata: [
                "path": .string(url.path),
                "supported": .bool(supportsExclusiveRenaming)
            ])
        }
        
        return true
    }

    /// Tracks an operation with the specified ID.
    ///
    /// - Parameter id: The ID of the operation to track
    private func trackOperation(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.insert(id)
        }
    }

    /// Untracks an operation with the specified ID.
    ///
    /// - Parameter id: The ID of the operation to untrack
    private func untrackOperation(_ id: UUID) {
        accessQueue.async(flags: .barrier) {
            self.activeOperations.remove(id)
        }
    }
}
