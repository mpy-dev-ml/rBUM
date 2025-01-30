//
//  rBUMApp.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI
import OSLog

private let logger = Logging.logger(for: .app)

@main
struct rBUMApp: App {
    private let repositoryStorage: RepositoryStorageProtocol
    private let repositoryCreationService: RepositoryCreationServiceProtocol
    private let resticService: ResticCommandServiceProtocol
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        let storage = RepositoryStorage()
        let resticService = ResticCommandService(credentialsManager: <#any CredentialsManagerProtocol#>, processExecutor: <#any ProcessExecutorProtocol#>)
        
        self.repositoryStorage = storage
        self.repositoryCreationService = RepositoryCreationService(
            resticService: resticService,
            repositoryStorage: storage
        )
        self.resticService = resticService
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                repositoryStorage: repositoryStorage,
                repositoryCreationService: repositoryCreationService,
                resticService: resticService
            )
                .onAppear {
                logger.infoMessage("ContentView appeared")
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    logger.infoMessage("Check for updates requested")
                    // TODO: Implement update check
                }
            }
            SidebarCommands()
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - App Delegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logging.logger(for: .appDelegate)
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.infoMessage("Application did finish launching")
        
        // Register for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleepNotification(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logger.infoMessage("Application will terminate")
        
        // Unregister observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // TODO: Check for any ongoing operations before allowing termination
        logger.infoMessage("Application requested to terminate")
        return .terminateNow
    }
    
    @objc private func handleSleepNotification(_ notification: Notification) {
        logger.infoMessage("System is going to sleep")
        // TODO: Handle sleep state
    }
    
    @objc private func handleWakeNotification(_ notification: Notification) {
        logger.infoMessage("System woke from sleep")
        // TODO: Handle wake state
    }
}
