/// Service for executing restic commands via XPC
class ResticCommandService {
    private let logger: LoggerProtocol
    private let fileManager: FileManager
    private let securityService: SecurityServiceProtocol
    private var xpcConnection: NSXPCConnection?
    private let sandboxDiagnostics: SandboxDiagnostics
    
    /// Temporary directory for command execution
    private var workingDirectory: URL {
        fileManager.temporaryDirectory.appendingPathComponent("dev.mpy.rBUM/restic", isDirectory: true)
    }
    
    init(
        logger: LoggerProtocol = LoggerFactory.createLogger(category: "ResticCommand"),
        fileManager: FileManager = .default,
        securityService: SecurityServiceProtocol,
        sandboxDiagnostics: SandboxDiagnostics = SandboxDiagnostics()
    ) {
        self.logger = logger
        self.fileManager = fileManager
        self.securityService = securityService
        self.sandboxDiagnostics = sandboxDiagnostics
        
        setupXPCConnection()
        
        // Create working directory
        try? fileManager.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true
        )
    }
    
    deinit {
        xpcConnection?.invalidate()
    }
    
    /// Execute a restic command
    /// - Parameters:
    ///   - command: The command to execute
    ///   - repository: The repository to operate on
    /// - Returns: The result of the command execution
    /// - Throws: ResticError if the command fails
    func executeResticCommand(_ command: ResticCommand, for repository: Repository) async throws -> ProcessResult {
        logger.debug("Executing restic command: \(command.rawValue, privacy: .public)")
        
        // Monitor file access
        sandboxDiagnostics.monitorFileAccess(url: repository.path, operation: "read")
        
        // Track resources we need to access
        var accessedResources: [URL] = []
        defer {
            // Always clean up resource access
            for resource in accessedResources {
                securityService.stopAccessing(resource)
            }
        }
        
        do {
            // Validate repository access
            guard securityService.startAccessing(repository.path) else {
                logger.error("Repository access denied: \(repository.path.path, privacy: .private)")
                throw ResticError.accessDenied(repository.path.path)
            }
            accessedResources.append(repository.path)
            
            // Ensure working directory exists and is accessible
            try await ensureWorkingDirectory()
            
            // Get restic service proxy
            guard let service = xpcConnection?.remoteObjectProxy as? ResticServiceProtocol else {
                throw ResticError.serviceUnavailable
            }
            
            // Execute command via XPC
            return try await withCheckedThrowingContinuation { continuation in
                let environment = [
                    "RESTIC_PASSWORD": repository.password,
                    "PATH": "/usr/local/bin:/usr/bin:/bin",
                    "TMPDIR": workingDirectory.path,
                    "HOME": fileManager.homeDirectoryForCurrentUser.path
                ]
                
                service.executeCommand(
                    "/usr/local/bin/restic",
                    arguments: buildArguments(command, for: repository),
                    environment: environment,
                    workingDirectory: workingDirectory.path
                ) { data, error in
                    if let error = error {
                        continuation.resume(throwing: ResticError.commandFailed(error.localizedDescription))
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(throwing: ResticError.noOutput)
                        return
                    }
                    
                    let result = ProcessResult(
                        standardOutput: String(data: data, encoding: .utf8) ?? "",
                        standardError: "",
                        exitCode: 0
                    )
                    
                    continuation.resume(returning: result)
                }
            }
            
        } catch {
            logger.error("Failed to execute command: \(error.localizedDescription, privacy: .private)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func setupXPCConnection() {
        xpcConnection = NSXPCConnection(serviceName: "dev.mpy.rBUM.ResticService")
        xpcConnection?.remoteObjectInterface = NSXPCInterface(with: ResticServiceProtocol.self)
        
        // Monitor IPC access
        sandboxDiagnostics.monitorIPCAccess("dev.mpy.rBUM.ResticService")
        
        xpcConnection?.invalidationHandler = { [weak self] in
            self?.logger.error("XPC connection invalidated", privacy: .public)
            self?.xpcConnection = nil
        }
        
        xpcConnection?.resume()
    }
    
    /// Ensure the working directory exists and is properly configured
    private func ensureWorkingDirectory() async throws {
        do {
            // Create working directory if it doesn't exist
            if !fileManager.fileExists(atPath: workingDirectory.path) {
                try fileManager.createDirectory(
                    at: workingDirectory,
                    withIntermediateDirectories: true,
                    attributes: [
                        FileAttributeKey.posixPermissions: 0o700
                    ]
                )
                logger.debug("Created working directory: \(workingDirectory.path, privacy: .private)")
            }
            
            // Clean up old files
            let contents = try fileManager.contentsOfDirectory(
                at: workingDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            let oldFiles = contents.filter { url in
                guard let creation = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                    return false
                }
                return Date().timeIntervalSince(creation) > 24 * 60 * 60 // 24 hours
            }
            
            for file in oldFiles {
                try fileManager.removeItem(at: file)
                logger.debug("Cleaned up old file: \(file.path, privacy: .private)")
            }
            
        } catch {
            logger.error("Failed to configure working directory: \(error.localizedDescription, privacy: .private)")
            throw ResticError.workingDirectoryError(error.localizedDescription)
        }
    }
    
    /// Build command arguments for restic
    private func buildArguments(_ command: ResticCommand, for repository: Repository) -> [String] {
        var args = [String]()
        
        // Add repository path
        args.append("--repo")
        args.append(repository.path.path)
        
        // Add command-specific arguments
        args.append(contentsOf: command.arguments)
        
        logger.debug("Built command arguments", privacy: .public)
        return args
    }
}

/// Represents a restic command with its arguments
enum ResticCommand {
    case initialize
    case check
    case backup([URL])
    case restore(String, to: URL)
    case snapshots
    case prune
    case unlock
    
    var arguments: [String] {
        switch self {
        case .initialize:
            return ["init"]
        case .check:
            return ["check"]
        case .backup(let urls):
            return ["backup"] + urls.map { $0.path }
        case .restore(let snapshot, let target):
            return ["restore", snapshot, "--target", target.path]
        case .snapshots:
            return ["snapshots"]
        case .prune:
            return ["prune"]
        case .unlock:
            return ["unlock"]
        }
    }
    
    var rawValue: String {
        switch self {
        case .initialize: return "init"
        case .check: return "check"
        case .backup: return "backup"
        case .restore: return "restore"
        case .snapshots: return "snapshots"
        case .prune: return "prune"
        case .unlock: return "unlock"
        }
    }
}

/// Errors that can occur during restic operations
enum ResticError: LocalizedError {
    case executableNotFound
    case accessDenied(String)
    case commandFailed(String)
    case workingDirectoryError(String)
    case serviceUnavailable
    case noOutput
    
    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Restic executable not found"
        case .accessDenied(let path):
            return "Access denied to path: \(path)"
        case .commandFailed(let error):
            return "Command failed: \(error)"
        case .workingDirectoryError(let error):
            return "Working directory error: \(error)"
        case .serviceUnavailable:
            return "Restic service is unavailable"
        case .noOutput:
            return "Command produced no output"
        }
    }
}
