import Foundation
@testable import rBUM

/// Mock data for testing
enum MockData {
    /// Repository mock data
    enum Repository {
        static let validRepository = rBUM.Repository(
            id: UUID(),
            name: "Test Repository",
            path: URL(fileURLWithPath: "/test/repo")
        )
        
        static let validCredentials = RepositoryCredentials(
            repositoryId: validRepository.id,
            password: "test123",
            repositoryPath: validRepository.path.path
        )
        
        static let invalidRepository = rBUM.Repository(
            id: UUID(),
            name: "",
            path: URL(fileURLWithPath: "")
        )
        
        static let repositories = [
            rBUM.Repository(
                id: UUID(),
                name: "Repo 1",
                path: URL(fileURLWithPath: "/test/repo1")
            ),
            rBUM.Repository(
                id: UUID(),
                name: "Repo 2",
                path: URL(fileURLWithPath: "/test/repo2")
            ),
            rBUM.Repository(
                id: UUID(),
                name: "Repo 3",
                path: URL(fileURLWithPath: "/test/repo3")
            )
        ]
        
        /// Mock repository paths
        static let repositoryPaths = [
            URL(fileURLWithPath: "/Users/test/Backups/Personal"),
            URL(fileURLWithPath: "/Users/test/Backups/Work"),
            URL(fileURLWithPath: "/Users/test/Backups/Projects")
        ]
        
        /// Mock repository names
        static let repositoryNames = [
            "Personal Backup",
            "Work Documents",
            "Project Files"
        ]
    }
    
    /// Backup mock data
    enum Backup {
        static let validBackup = BackupOperation(
            id: UUID(),
            name: "Test Backup",
            paths: [URL(fileURLWithPath: "/test/data")],
            tags: ["test", "backup"]
        )
        
        static let validProgress = BackupProgress(
            totalFiles: 100,
            processedFiles: 50,
            totalBytes: 1024 * 1024,
            processedBytes: 512 * 1024
        )
        
        static let validStatus = BackupStatus.running
        
        static let sourcePaths = [
            URL(fileURLWithPath: "/test/source1"),
            URL(fileURLWithPath: "/test/source2")
        ]
        
        static let tags = ["daily", "test", "important"]
        
        static let progress = BackupProgress(
            bytesProcessed: 1024,
            totalBytes: 2048,
            filesProcessed: 10,
            totalFiles: 20,
            currentFile: "/test/file.txt",
            percentage: 50
        )
        
        /// Mock backup paths
        static let backupPaths = [
            URL(fileURLWithPath: "/Users/test/Documents"),
            URL(fileURLWithPath: "/Users/test/Pictures"),
            URL(fileURLWithPath: "/Users/test/Desktop")
        ]
        
        /// Mock backup tags
        static let backupTags = [
            ["documents", "personal"],
            ["pictures", "family"],
            ["work", "projects"]
        ]
    }
    
    /// Error mock data
    enum Error {
        static let repositoryError = NSError(
            domain: "com.rbum.repository",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Repository error"]
        )
        
        static let backupError = NSError(
            domain: "com.rbum.backup",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Backup error"]
        )
        
        static let fileOperationError = NSError(
            domain: "test.error",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "File operation failed"]
        )
        
        static let networkError = NSError(
            domain: "test.error",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Network operation failed"]
        )
        
        static let authenticationError = NSError(
            domain: "test.error",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Authentication failed"]
        )
        
        /// Mock errors
        static let errors = [
            NSError(
                domain: "com.test.backup",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Failed to initialize repository"]
            ),
            NSError(
                domain: "com.test.backup",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Backup operation failed"]
            )
        ]
    }
    
    /// Snapshot mock data
    enum Snapshot {
        static let validSnapshot = rBUM.Snapshot(
            id: "test123",
            time: Date(),
            paths: ["/test/path"],
            hostname: "test-host",
            username: "test-user",
            tags: ["test"]
        )
        
        static let snapshots = [
            rBUM.Snapshot(
                id: "snap1",
                time: Date().addingTimeInterval(-86400),
                paths: ["/test/path1"],
                hostname: "host1",
                username: "user1",
                tags: ["daily"]
            ),
            rBUM.Snapshot(
                id: "snap2",
                time: Date(),
                paths: ["/test/path2"],
                hostname: "host2",
                username: "user2",
                tags: ["weekly"]
            )
        ]
    }
    
    /// Process mock data
    enum Process {
        static let successOutput = """
        {
            "status": "success",
            "message": "Operation completed"
        }
        """
        
        static let errorOutput = """
        {
            "status": "error",
            "message": "Operation failed"
        }
        """
        
        static let snapshotListOutput = """
        [
            {
                "id": "snap1",
                "time": "2025-01-30T10:00:00Z",
                "hostname": "test-host",
                "username": "test-user",
                "paths": ["/test/path"],
                "tags": ["test"]
            }
        ]
        """
    }
    
    /// Authentication mock data
    enum Auth {
        static func createWithAuth(_ type: AuthType) -> rBUM.Repository {
            switch type {
            case .password:
                return rBUM.Repository(
                    id: UUID(),
                    name: "Password Repository",
                    path: URL(fileURLWithPath: "/test/password-repo")
                )
            case .keyFile:
                return rBUM.Repository(
                    id: UUID(),
                    name: "Key File Repository",
                    path: URL(fileURLWithPath: "/test/keyfile-repo")
                )
            case .multiKey:
                return rBUM.Repository(
                    id: UUID(),
                    name: "Multi-Key Repository",
                    path: URL(fileURLWithPath: "/test/multikey-repo")
                )
            }
        }
        
        static func createPassword() -> RepositoryCredentials {
            RepositoryCredentials(password: "test_password", keyFile: nil)
        }
        
        static func createKeyFile() -> RepositoryCredentials {
            RepositoryCredentials(
                password: nil,
                keyFile: URL(fileURLWithPath: "/test/keys/key1.pem")
            )
        }
        
        static func createMultipleKeyFiles() -> RepositoryCredentials {
            RepositoryCredentials(
                password: nil,
                keyFilePaths: [
                    "/test/keys/key1.pem",
                    "/test/keys/key2.pem",
                    "/test/keys/key3.pem"
                ]
            )
        }
    }
    
    /// Cache mock data
    enum Cache {
        static let validCacheData = """
        {
            "snapshots": [],
            "stats": {
                "total_size": 1024,
                "total_files": 100
            }
        }
        """.data(using: .utf8)!
        
        static let oldCacheData = """
        {
            "version": 1,
            "snapshots": [],
            "stats": {
                "size": 512,
                "files": 50
            }
        }
        """.data(using: .utf8)!
    }
    
    /// Operation mock data
    enum Operation {
        static let validOperations = [
            BackupOperation(
                id: UUID(),
                source: "/test/source1",
                destination: "/test/dest1",
                type: .full
            ),
            BackupOperation(
                id: UUID(),
                source: "/test/source2",
                destination: "/test/dest2",
                type: .incremental
            )
        ]
        
        static let backgroundOperation = BackupOperation(
            id: UUID(),
            source: "/test/background/source",
            destination: "/test/background/dest",
            type: .full,
            isBackgroundOperation: true
        )
        
        static let networkOperation = BackupOperation(
            id: UUID(),
            source: "/test/network/source",
            destination: "sftp://test.server/backup",
            type: .full
        )
        
        static let largeOperation = BackupOperation(
            id: UUID(),
            source: "/test/large/source",
            destination: "/test/large/dest",
            type: .full,
            expectedSize: 1_000_000_000 // 1GB
        )
        
        static let permissionOperation = BackupOperation(
            id: UUID(),
            source: "/test/permission/source",
            destination: "/test/permission/dest",
            type: .full
        )
        
        static func createWithSource(_ source: String) -> BackupOperation {
            BackupOperation(
                id: UUID(),
                source: source,
                destination: "/test/dest",
                type: .full
            )
        }
    }
    
    /// Restic mock data
    enum Restic {
        static let commandData = [
            (command: "backup", expectedCommand: "restic backup", expectedOutput: "Successfully backed up"),
            (command: "restore", expectedCommand: "restic restore", expectedOutput: "Successfully restored"),
            (command: "check", expectedCommand: "restic check", expectedOutput: "No errors found")
        ]
        
        static let repositoryData = [
            (operation: "init", repository: Repository.validRepository, expectedCommandPart: "init"),
            (operation: "check", repository: Repository.validRepository, expectedCommandPart: "check"),
            (operation: "prune", repository: Repository.validRepository, expectedCommandPart: "prune")
        ]
        
        static let jsonOutputData = [
            (command: "snapshots", expectedJSON: """
            {
                "snapshots": [
                    {
                        "id": "test123",
                        "time": "2025-01-31T12:00:00Z",
                        "paths": ["/test"]
                    }
                ]
            }
            """),
            (command: "stats", expectedJSON: """
            {
                "total_size": 1024,
                "total_files": 100
            }
            """)
        ]
        
        static let testRepository = Repository.validRepository
        static let longRunningCommand = "backup --large-repo"
        static let largeBackupData = BackupData(
            id: UUID(),
            sourcePath: "/test/large",
            packSize: 20_000_000 // 20MB chunks
        )
    }
    
    /// History mock data
    enum History {
        static let validId = "hist_123"
        static let validTimestamp = Date(timeIntervalSince1970: 1706705400) // 2025-01-31 12:30:00 UTC
        
        static let entries = [
            BackupHistoryEntry(
                id: "hist_1",
                timestamp: Date(timeIntervalSince1970: 1706619000), // 2025-01-30 12:30:00 UTC
                status: .completed,
                repository: Repository.validRepository,
                snapshot: Snapshot.validSnapshot,
                duration: 300,
                bytesProcessed: 1024 * 1024,
                filesProcessed: 100
            ),
            BackupHistoryEntry(
                id: "hist_2",
                timestamp: Date(timeIntervalSince1970: 1706532600), // 2025-01-29 12:30:00 UTC
                status: .failed,
                repository: Repository.validRepository,
                snapshot: nil,
                duration: 60,
                bytesProcessed: 512 * 1024,
                filesProcessed: 50,
                error: Error.networkError
            ),
            BackupHistoryEntry(
                id: "hist_3",
                timestamp: Date(timeIntervalSince1970: 1706446200), // 2025-01-28 12:30:00 UTC
                status: .cancelled,
                repository: Repository.validRepository,
                snapshot: nil,
                duration: 30,
                bytesProcessed: 256 * 1024,
                filesProcessed: 25
            )
        ]
        
        static let statuses: [(BackupStatus, String)] = [
            (.completed, "Completed"),
            (.failed, "Failed"),
            (.cancelled, "Cancelled"),
            (.inProgress, "In Progress"),
            (.queued, "Queued"),
            (.paused, "Paused")
        ]
    }
    
    /// Schedule mock data
    enum Schedule {
        static let validSchedule = BackupSchedule(
            id: UUID(),
            name: "Daily Backup",
            repository: Repository.validRepository,
            frequency: .daily,
            startTime: DateComponents(hour: 2, minute: 0), // 2 AM
            enabled: true
        )
        
        static let schedules = [
            BackupSchedule(
                id: UUID(),
                name: "Daily at 2 AM",
                repository: Repository.repositories[0],
                frequency: .daily,
                startTime: DateComponents(hour: 2, minute: 0),
                enabled: true
            ),
            BackupSchedule(
                id: UUID(),
                name: "Weekly on Sunday",
                repository: Repository.repositories[1],
                frequency: .weekly,
                startTime: DateComponents(weekday: 1, hour: 3, minute: 0),
                enabled: true
            ),
            BackupSchedule(
                id: UUID(),
                name: "Monthly on 1st",
                repository: Repository.repositories[2],
                frequency: .monthly,
                startTime: DateComponents(day: 1, hour: 4, minute: 0),
                enabled: true
            )
        ]
        
        static let frequencies: [(BackupFrequency, String)] = [
            (.hourly, "Every hour"),
            (.daily, "Every day"),
            (.weekly, "Every week"),
            (.monthly, "Every month"),
            (.custom(interval: 3600), "Every hour (custom)"),
            (.custom(interval: 86400), "Every day (custom)")
        ]
        
        static let nextExecutionTimes = [
            (schedule: validSchedule, currentTime: Date(timeIntervalSince1970: 1706705400), // 2025-01-31 12:30:00 UTC
             expectedNext: Date(timeIntervalSince1970: 1706749200)), // 2025-02-01 02:00:00 UTC
            (schedule: schedules[0], currentTime: Date(timeIntervalSince1970: 1706705400),
             expectedNext: Date(timeIntervalSince1970: 1706749200)),
            (schedule: schedules[1], currentTime: Date(timeIntervalSince1970: 1706705400),
             expectedNext: Date(timeIntervalSince1970: 1706932800)), // Next Sunday at 3 AM
            (schedule: schedules[2], currentTime: Date(timeIntervalSince1970: 1706705400),
             expectedNext: Date(timeIntervalSince1970: 1707264000)) // Next 1st at 4 AM
        ]
        
        /// Mock backup schedules
        static let schedules = [
            BackupSchedule(
                id: UUID(),
                name: "Daily Documents",
                frequency: .daily,
                time: Date(),
                paths: [Backup.backupPaths[0]],
                tags: Backup.backupTags[0],
                enabled: true
            ),
            BackupSchedule(
                id: UUID(),
                name: "Weekly Pictures",
                frequency: .weekly,
                time: Date(),
                paths: [Backup.backupPaths[1]],
                tags: Backup.backupTags[1],
                enabled: true
            )
        ]
    }
    
    /// Configuration mock data
    enum Configuration {
        static let validId = "config_123"
        static let validName = "Test Configuration"
        static let validSourcePaths = [
            "/Users/test/Documents",
            "/Users/test/Pictures"
        ]
        static let validExcludePatterns = [
            "*.tmp",
            "*.cache",
            ".DS_Store"
        ]
        static let validIncludePatterns = [
            "*.doc",
            "*.pdf",
            "*.jpg"
        ]
        
        static let configurations = [
            BackupConfiguration(
                id: "config_1",
                name: "Documents Backup",
                sourcePaths: ["/Users/test/Documents"],
                excludePatterns: ["*.tmp"],
                includePatterns: ["*.doc", "*.pdf"],
                schedule: Schedule.schedules[0],
                repository: Repository.repositories[0],
                isEnabled: true
            ),
            BackupConfiguration(
                id: "config_2",
                name: "Pictures Backup",
                sourcePaths: ["/Users/test/Pictures"],
                excludePatterns: [".DS_Store"],
                includePatterns: ["*.jpg", "*.png"],
                schedule: Schedule.schedules[1],
                repository: Repository.repositories[1],
                isEnabled: true
            ),
            BackupConfiguration(
                id: "config_3",
                name: "Projects Backup",
                sourcePaths: ["/Users/test/Projects"],
                excludePatterns: ["node_modules", "*.log"],
                includePatterns: ["*.swift", "*.json"],
                schedule: Schedule.schedules[2],
                repository: Repository.repositories[2],
                isEnabled: false
            )
        ]
        
        static let validationCases = [
            (config: configurations[0], expectedValid: true, description: "Valid configuration"),
            (config: BackupConfiguration(
                id: "invalid_1",
                name: "",  // Invalid: Empty name
                sourcePaths: validSourcePaths,
                excludePatterns: validExcludePatterns,
                includePatterns: validIncludePatterns,
                schedule: Schedule.validSchedule,
                repository: Repository.validRepository,
                isEnabled: true
            ), expectedValid: false, description: "Invalid: Empty name"),
            (config: BackupConfiguration(
                id: "invalid_2",
                name: validName,
                sourcePaths: [],  // Invalid: No source paths
                excludePatterns: validExcludePatterns,
                includePatterns: validIncludePatterns,
                schedule: Schedule.validSchedule,
                repository: Repository.validRepository,
                isEnabled: true
            ), expectedValid: false, description: "Invalid: No source paths"),
            (config: BackupConfiguration(
                id: "invalid_3",
                name: validName,
                sourcePaths: validSourcePaths,
                excludePatterns: validExcludePatterns,
                includePatterns: validIncludePatterns,
                schedule: Schedule.validSchedule,
                repository: Repository.validRepository,
                isEnabled: true,
                maxRetention: -1  // Invalid: Negative retention
            ), expectedValid: false, description: "Invalid: Negative retention")
        ]
    }
}
