//
//  rBUMApp.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "dev.mpy.rBUM", category: "App")

@main
struct rBUMApp: App {
    private let processExecutor = ProcessExecutor()
    private let credentialsManager: CredentialsManagerProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let resticService: ResticCommandServiceProtocol
    private let repositoryCreationService: RepositoryCreationServiceProtocol
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Initialize services
        let keychainService = KeychainService()
        self.credentialsManager = KeychainCredentialsManager(keychainService: keychainService)
        let storage = RepositoryStorage()
        self.repositoryStorage = storage
        self.resticService = ResticCommandService(
            fileManager: .default,
            logger: Logger(subsystem: "dev.mpy.rBUM", category: "ResticCommand")
        )
        self.repositoryCreationService = RepositoryCreationService(
            resticService: resticService,
            repositoryStorage: storage
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(credentialsManager: credentialsManager)
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
    private let logger = Logger(subsystem: "dev.mpy.rBUM", category: "AppDelegate")
    
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
