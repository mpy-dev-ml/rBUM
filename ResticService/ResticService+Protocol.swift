import Core
import Foundation
import os.log

// MARK: - Protocol Implementation

extension ResticService {
    /// Initialises a new Restic repository at the specified URL
    ///
    /// This method:
    /// 1. Creates a security-scoped access instance for the repository URL
    /// 2. Starts accessing the repository URL
    /// 3. Executes the `restic init` command
    /// 4. Records the operation result
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the repository to initialise
    ///   - password: The password for the repository
    ///   - reply: A callback with the result of the operation
    func initialiseRepository(
        at repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let repoAccess = try self.createSecurityScopedAccess(from: repositoryURL)
                defer { self.stopAccessing(repoAccess) }
                
                guard self.startAccessing(repoAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                let environment = ["RESTIC_PASSWORD": password]
                let arguments = ["init", "--repo", repoAccess.url.path]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Repository initialised at \(repoAccess.url.path, privacy: .private)")
                reply(result)
            } catch {
                self.logger.error("Failed to initialise repository: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    /// Creates a new backup of the specified source paths to the repository
    ///
    /// This method:
    /// 1. Creates security-scoped access instances for the repository and source paths
    /// 2. Starts accessing the repository and source paths
    /// 3. Executes the `restic backup` command
    /// 4. Records the operation result
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the repository to backup to
    ///   - sourcePaths: The URLs of the source paths to backup
    ///   - password: The password for the repository
    ///   - excludePatterns: Patterns to exclude from the backup
    ///   - reply: A callback with the result of the operation
    func createBackup(
        repository repositoryURL: Data,
        sourcePaths: [Data],
        password: String,
        excludePatterns: [String],
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let repoAccess = try self.createSecurityScopedAccess(from: repositoryURL)
                defer { self.stopAccessing(repoAccess) }
                
                guard self.startAccessing(repoAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                // Resolve and access all source paths
                let sourceAccesses = try sourcePaths.map { try self.createSecurityScopedAccess(from: $0) }
                defer { sourceAccesses.forEach { self.stopAccessing($0) } }
                
                // Start accessing all sources
                for access in sourceAccesses {
                    guard self.startAccessing(access) else {
                        throw ResticXPCError.accessDenied
                    }
                }
                
                var arguments = ["backup", "--repo", repoAccess.url.path]
                
                // Add exclude patterns
                for pattern in excludePatterns {
                    arguments.append(contentsOf: ["--exclude", pattern])
                }
                
                // Add source paths
                arguments.append(contentsOf: sourceAccesses.map { $0.url.path })
                
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Backup completed to \(repoAccess.url.path, privacy: .private)")
                reply(result)
            } catch {
                self.logger.error("Backup failed: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    /// Lists all snapshots in the repository
    ///
    /// This method:
    /// 1. Creates a security-scoped access instance for the repository URL
    /// 2. Starts accessing the repository URL
    /// 3. Executes the `restic snapshots` command
    /// 4. Records the operation result
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the repository to list snapshots for
    ///   - password: The password for the repository
    ///   - reply: A callback with the result of the operation
    func listSnapshots(
        repository repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let repoAccess = try self.createSecurityScopedAccess(from: repositoryURL)
                defer { self.stopAccessing(repoAccess) }
                
                guard self.startAccessing(repoAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                let arguments = ["snapshots", "--repo", repoAccess.url.path, "--json"]
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                reply(result)
            } catch {
                self.logger.error("Failed to list snapshots: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    /// Restores a snapshot from the repository to the specified target path
    ///
    /// This method:
    /// 1. Creates security-scoped access instances for the repository and target paths
    /// 2. Starts accessing the repository and target paths
    /// 3. Executes the `restic restore` command
    /// 4. Records the operation result
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the repository to restore from
    ///   - targetPath: The URL of the target path to restore to
    ///   - snapshotID: The ID of the snapshot to restore
    ///   - password: The password for the repository
    ///   - paths: Optional paths to restore
    ///   - reply: A callback with the result of the operation
    func restore(
        repository repositoryURL: Data,
        to targetPath: Data,
        snapshot snapshotID: String,
        password: String,
        paths: [String],
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let repoAccess = try self.createSecurityScopedAccess(from: repositoryURL)
                let targetAccess = try self.createSecurityScopedAccess(from: targetPath)
                
                defer {
                    self.stopAccessing(repoAccess)
                    self.stopAccessing(targetAccess)
                }
                
                guard self.startAccessing(repoAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                guard self.startAccessing(targetAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                var arguments = [
                    "restore",
                    "--repo", repoAccess.url.path,
                    "--target", targetAccess.url.path,
                    snapshotID
                ]
                
                // Add specific paths if provided
                if !paths.isEmpty {
                    arguments.append(contentsOf: paths)
                }
                
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                self.logger.info("Restore completed to \(targetAccess.url.path, privacy: .private)")
                reply(result)
            } catch {
                self.logger.error("Restore failed: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    /// Verifies the integrity of the repository
    ///
    /// This method:
    /// 1. Creates a security-scoped access instance for the repository URL
    /// 2. Starts accessing the repository URL
    /// 3. Executes the `restic check` command
    /// 4. Records the operation result
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the repository to verify
    ///   - password: The password for the repository
    ///   - reply: A callback with the result of the operation
    func verifyRepository(
        at repositoryURL: Data,
        password: String,
        with reply: @escaping (ResticCommandResult) -> Void
    ) {
        queue.async {
            do {
                let repoAccess = try self.createSecurityScopedAccess(from: repositoryURL)
                defer { self.stopAccessing(repoAccess) }
                
                guard self.startAccessing(repoAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                let arguments = ["check", "--repo", repoAccess.url.path]
                let environment = ["RESTIC_PASSWORD": password]
                
                let result = try self.executeResticCommand(
                    arguments: arguments,
                    environment: environment
                )
                
                reply(result)
            } catch {
                self.logger.error("Repository verification failed: \(error.localizedDescription)")
                reply(ResticCommandResult(
                    output: "",
                    error: error.localizedDescription,
                    exitCode: 1
                ))
            }
        }
    }
    
    /// Cancels the current operation
    ///
    /// This method:
    /// 1. Terminates the current task
    /// 2. Records the cancellation as a security operation
    /// 3. Returns the success status
    ///
    /// - Parameter reply: A callback with the result of the cancellation
    func cancelOperation(with reply: @escaping (Bool) -> Void) {
        queue.async {
            guard let task = self.currentTask else {
                reply(false)
                return
            }
            
            task.terminate()
            self.currentTask = nil
            
            reply(true)
        }
    }
    
    /// Validates a security-scoped bookmark
    ///
    /// This method:
    /// 1. Creates a security-scoped access instance for the bookmark
    /// 2. Starts accessing the bookmark
    /// 3. Records the validation result
    ///
    /// - Parameters:
    ///   - bookmarkData: The security-scoped bookmark data
    ///   - reply: A callback with the result of the validation
    func validateBookmark(_ bookmarkData: Data, with reply: @escaping (Bool, Error?) -> Void) {
        queue.async {
            do {
                let repoAccess = try self.createSecurityScopedAccess(from: bookmarkData)
                defer { self.stopAccessing(repoAccess) }
                
                guard self.startAccessing(repoAccess) else {
                    throw ResticXPCError.accessDenied
                }
                
                reply(true, nil)
            } catch {
                self.logger.error("Bookmark validation failed: \(error.localizedDescription)")
                reply(false, error)
            }
        }
    }
}
