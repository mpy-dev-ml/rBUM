//
//  rBUMApp.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI
import Core

private let logger = LoggerFactory.createLogger(category: "App")

@main
struct rBUMApp: App {
    private let processExecutor = ProcessExecutor()
    private let credentialsManager: KeychainCredentialsManagerProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let resticService: ResticCommandServiceProtocol
    private let repositoryCreationService: RepositoryCreationServiceProtocol
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Initialize dependencies
        let fileManager = FileManager.default
        let securityService = SecurityService()
        let dateProvider = DefaultDateProvider()
        let notificationCenter = NotificationCenter.default
        
        // Initialize repository services
        self.credentialsManager = KeychainCredentialsManager(
            securityService: securityService,
            dateProvider: dateProvider,
            notificationCenter: notificationCenter
        )
        
        self.repositoryStorage = RepositoryStorage(
            fileManager: fileManager,
            securityService: securityService,
            dateProvider: dateProvider,
            notificationCenter: notificationCenter
        )
        
        self.resticService = ResticCommandService(
            fileManager: fileManager,
            securityService: securityService,
            processExecutor: processExecutor,
            dateProvider: dateProvider
        )
        
        self.repositoryCreationService = RepositoryCreationService(
            fileManager: fileManager,
            securityService: securityService,
            repositoryService: resticService,
            credentialsManager: credentialsManager,
            repositoryStorage: repositoryStorage,
            dateProvider: dateProvider,
            notificationCenter: notificationCenter
        )
        
        logger.debug("App initialized", privacy: .public)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                credentialsManager: credentialsManager,
                creationService: repositoryCreationService
            )
            .onAppear {
                logger.info("ContentView appeared")
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    logger.info("Check for updates requested")
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
    private let logger = LoggerFactory.createLogger(category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        
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
        logger.info("Application will terminate")
        
        // Unregister observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // TODO: Check for any ongoing operations before allowing termination
        logger.info("Application requested to terminate")
        return .terminateNow
    }
    
    @objc private func handleSleepNotification(_ notification: Notification) {
        logger.info("System is going to sleep")
        // TODO: Handle sleep state
    }
    
    @objc private func handleWakeNotification(_ notification: Notification) {
        logger.info("System woke from sleep")
        // TODO: Handle wake state
    }
}
