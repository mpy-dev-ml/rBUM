import Core
import Foundation
import SwiftUI

@MainActor
final class BackupConfigurationViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var configurations: [BackupConfiguration] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let configurationService: BackupConfigurationService
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    init(
        configurationService: BackupConfigurationService,
        logger: LoggerProtocol
    ) {
        self.configurationService = configurationService
        self.logger = logger
    }
    
    // MARK: - Configuration Management
    
    /// Load saved configurations
    func loadConfigurations() {
        Task {
            do {
                isLoading = true
                error = nil
                
                try await configurationService.loadConfigurations()
                configurations = await configurationService.getConfigurations()
                
                logger.debug("Loaded \(configurations.count) configurations", privacy: .public)
            } catch {
                logger.error("Failed to load configurations: \(error.localizedDescription)", privacy: .public)
                self.error = error
            }
            isLoading = false
        }
    }
    
    /// Create a new backup configuration
    /// - Parameters:
    ///   - name: Name of the backup configuration
    ///   - description: Optional description of what this backup does
    ///   - enabled: Whether this backup configuration is enabled
    ///   - schedule: Schedule for running the backup
    ///   - sources: Source locations to backup
    ///   - includeHidden: Whether to include hidden files in backup
    ///   - verifyAfterBackup: Whether to verify after backup completion
    ///   - repository: Repository to use for backup
    func createConfiguration(
        name: String,
        description: String? = nil,
        enabled: Bool = true,
        schedule: BackupSchedule? = nil,
        sources: [URL],
        includeHidden: Bool = false,
        verifyAfterBackup: Bool = true,
        repository: Repository? = nil
    ) {
        Task {
            do {
                error = nil
                
                _ = try await configurationService.createConfiguration(
                    name: name,
                    description: description,
                    enabled: enabled,
                    schedule: schedule,
                    sources: sources,
                    includeHidden: includeHidden,
                    verifyAfterBackup: verifyAfterBackup,
                    repository: repository
                )
                
                // Refresh configurations list
                configurations = await configurationService.getConfigurations()
                
                logger.debug("Created new configuration: \(name)", privacy: .public)
            } catch {
                logger.error("Failed to create configuration: \(error.localizedDescription)", privacy: .public)
                self.error = error
            }
        }
    }
    
    /// Start accessing sources for a backup configuration
    /// - Parameter configurationId: ID of the configuration to start accessing
    func startAccessing(configurationId: UUID) {
        Task {
            do {
                error = nil
                
                try await configurationService.startAccessing(configurationId: configurationId)
                configurations = await configurationService.getConfigurations()
                
                logger.debug("Started accessing configuration: \(configurationId)", privacy: .public)
            } catch {
                logger.error("Failed to start accessing configuration: \(error.localizedDescription)", privacy: .public)
                self.error = error
            }
        }
    }
    
    /// Stop accessing sources for a backup configuration
    /// - Parameter configurationId: ID of the configuration to stop accessing
    func stopAccessing(configurationId: UUID) {
        Task {
            error = nil
            
            await configurationService.stopAccessing(configurationId: configurationId)
            configurations = await configurationService.getConfigurations()
            
            logger.debug("Stopped accessing configuration: \(configurationId)", privacy: .public)
        }
    }
}
