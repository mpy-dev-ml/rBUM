//
//  rBUMApp.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI
import Core
import Foundation

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
        let xpcService = ResticXPCService()
        let securityService = SecurityService(xpcService: xpcService)
        let dateProvider = DateProvider()
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
            securityService: securityService
        )
        
        self.repositoryCreationService = RepositoryCreationService(
            fileManager: fileManager,
            securityService: securityService,
            credentialsManager: credentialsManager,
            repositoryStorage: repositoryStorage,
            resticService: resticService
        )
        
        logger.debug("App initialized")
        
        // Setup app delegate
        setupAppDelegate()
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
                    checkForUpdates()
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
            }
            SidebarCommands()
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
    
    // MARK: - Private Methods
    
    private func setupAppDelegate() {
        logger.debug("Setting up app delegate")
        
        // Register for notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleAppTermination()
        }
    }
    
    private func handleAppTermination() {
        logger.debug("Handling app termination")
        
        // Clean up resources
        cleanupResources()
        
        // Save state
        saveApplicationState()
    }
    
    private func cleanupResources() {
        logger.debug("Cleaning up resources")
    }
    
    private func saveApplicationState() {
        logger.debug("Saving application state")
    }
    
    private func checkForUpdates() {
        logger.debug("Checking for updates")
        
        // TODO: Implement update checking
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
