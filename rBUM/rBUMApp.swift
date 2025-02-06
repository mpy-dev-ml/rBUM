//
//  rBUMApp.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI
import Core
import Foundation

private let logger = LoggerFactory.createLogger(category: "App")

@main
struct RBUMApp: App {
    private let processExecutor = ProcessExecutor()
    private let credentialsManager: KeychainCredentialsManagerProtocol
    private let repositoryStorage: RepositoryStorageProtocol
    private let resticService: ResticCommandServiceProtocol
    private let repositoryCreationService: RepositoryCreationServiceProtocol
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Initialize dependencies
        let fileManager: FileManagerProtocol = DefaultFileManager()
        let dateProvider: DateProviderProtocol = DateProvider()
        let notificationCenter = NotificationCenter.default
        
        // Initialize security-related services
        let securityService = ServiceFactory.createSecurityService(logger: logger)
        let keychainService = ServiceFactory.createKeychainService(logger: logger)
        let bookmarkService = ServiceFactory.createBookmarkService(
            logger: logger,
            securityService: securityService,
            keychainService: keychainService
        )
        
        let sandboxMonitor = SandboxMonitor(
            logger: logger,
            securityService: securityService
        )
        
        let xpcService = ServiceFactory.createXPCService(
            logger: logger,
            securityService: securityService
        )
        
        // Initialize repository services
        self.credentialsManager = KeychainCredentialsManager(
            logger: logger,
            keychainService: keychainService,
            dateProvider: dateProvider,
            notificationCenter: notificationCenter
        )
        
        self.repositoryStorage = DefaultRepositoryStorage(
            logger: logger,
            fileManager: fileManager,
            dateProvider: dateProvider,
            notificationCenter: notificationCenter
        )
        
        self.resticService = ResticCommandService(
            logger: logger,
            securityService: securityService,
            xpcService: ServiceFactory.createXPCService(logger: logger, securityService: securityService),
            keychainService: keychainService
        )
        
        self.repositoryCreationService = DefaultRepositoryCreationService(
            logger: logger,
            securityService: securityService,
            bookmarkService: bookmarkService,
            keychainService: keychainService
        )
        
        logger.debug("App initialized",
                    file: #file,
                    function: #function,
                    line: #line)
        
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
                logger.info("ContentView appeared",
                           file: #file,
                           function: #function,
                           line: #line)
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
        logger.debug("Setting up app delegate",
                    file: #file,
                    function: #function,
                    line: #line)
        
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
        logger.debug("Handling app termination",
                    file: #file,
                    function: #function,
                    line: #line)
        
        // Clean up resources
        cleanupResources()
        
        // Save state
        saveApplicationState()
    }
    
    private func cleanupResources() {
        logger.debug("Cleaning up resources",
                    file: #file,
                    function: #function,
                    line: #line)
    }
    
    private func saveApplicationState() {
        logger.debug("Saving application state",
                    file: #file,
                    function: #function,
                    line: #line)
    }
    
    private func checkForUpdates() {
        logger.debug("Checking for updates",
                    file: #file,
                    function: #function,
                    line: #line)
        
        // TODO: Implement update checking
    }
}

// MARK: - App Delegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = LoggerFactory.createLogger(category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching",
                   file: #file,
                   function: #function,
                   line: #line)
        
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
        logger.info("Application will terminate",
                   file: #file,
                   function: #function,
                   line: #line)
        
        // Unregister observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        logger.info("Application requested to terminate",
                   file: #file,
                   function: #function,
                   line: #line)
        return .terminateNow
    }
    
    @objc private func handleSleepNotification(_ notification: Notification) {
        logger.info("System is going to sleep",
                   file: #file,
                   function: #function,
                   line: #line)
        // TODO: Handle sleep state
    }
    
    @objc private func handleWakeNotification(_ notification: Notification) {
        logger.info("System woke from sleep",
                   file: #file,
                   function: #function,
                   line: #line)
        // TODO: Handle wake state
    }
}
