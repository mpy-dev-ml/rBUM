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

import Core
import Foundation
import SwiftUI

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
        let dependencies = setupCoreDependencies()
        let securityServices = setupSecurityServices(dependencies)
        
        credentialsManager = setupCredentialsManager(
            dependencies: dependencies,
            keychainService: securityServices.keychainService
        )
        
        repositoryStorage = setupRepositoryStorage(dependencies.fileManager)
        
        resticService = setupResticService(
            dependencies: dependencies,
            securityServices: securityServices
        )
        
        repositoryCreationService = setupRepositoryCreationService(
            dependencies: dependencies,
            securityServices: securityServices
        )
        
        logger.debug(
            "App initialized",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Setup app delegate
        setupAppDelegate()
    }
    
    private struct CoreDependencies {
        let fileManager: FileManagerProtocol
        let dateProvider: DateProviderProtocol
        let notificationCenter: NotificationCenter
    }
    
    private struct SecurityServices {
        let securityService: SecurityServiceProtocol
        let keychainService: KeychainServiceProtocol
        let bookmarkService: BookmarkServiceProtocol
        let sandboxMonitor: SandboxMonitor
        let xpcService: ResticXPCServiceProtocol
    }
    
    private func setupCoreDependencies() -> CoreDependencies {
        CoreDependencies(
            fileManager: DefaultFileManager(),
            dateProvider: DateProvider(),
            notificationCenter: .default
        )
    }
    
    private func setupSecurityServices(_ dependencies: CoreDependencies) -> SecurityServices {
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
        ) as! ResticXPCServiceProtocol
        
        return SecurityServices(
            securityService: securityService,
            keychainService: keychainService,
            bookmarkService: bookmarkService,
            sandboxMonitor: sandboxMonitor,
            xpcService: xpcService
        )
    }
    
    private func setupCredentialsManager(
        dependencies: CoreDependencies,
        keychainService: KeychainServiceProtocol
    ) -> KeychainCredentialsManagerProtocol {
        KeychainCredentialsManager(
            logger: logger,
            keychainService: keychainService,
            dateProvider: dependencies.dateProvider,
            notificationCenter: dependencies.notificationCenter
        )
    }
    
    private func setupRepositoryStorage(
        _ fileManager: FileManagerProtocol
    ) -> RepositoryStorageProtocol {
        do {
            return try DefaultRepositoryStorage(
                fileManager: fileManager,
                logger: logger
            )
        } catch {
            logger.error(
                "Failed to initialize repository storage: \(error.localizedDescription)",
                file: #file,
                function: #function,
                line: #line
            )
            fatalError("Failed to initialize repository storage: \(error.localizedDescription)")
        }
    }
    
    private func setupResticService(
        dependencies: CoreDependencies,
        securityServices: SecurityServices
    ) -> ResticCommandServiceProtocol {
        ResticCommandService(
            logger: logger,
            securityService: securityServices.securityService,
            xpcService: securityServices.xpcService,
            keychainService: securityServices.keychainService
        ) as! any ResticCommandServiceProtocol
    }
    
    private func setupRepositoryCreationService(
        dependencies: CoreDependencies,
        securityServices: SecurityServices
    ) -> RepositoryCreationServiceProtocol {
        DefaultRepositoryCreationService(
            logger: logger,
            securityService: resticService as! SecurityServiceProtocol,
            bookmarkService: securityServices.bookmarkService,
            keychainService: securityServices.keychainService
        ) as! any RepositoryCreationServiceProtocol
    }

    // MARK: - Private Methods

    private func setupAppDelegate() {
        logger.debug(
            "Setting up app delegate",
            file: #file,
            function: #function,
            line: #line
        )

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
        logger.debug(
            "Handling app termination",
            file: #file,
            function: #function,
            line: #line
        )

        // Clean up resources
        cleanupResources()

        // Save state
        saveApplicationState()
    }

    private func cleanupResources() {
        logger.debug(
            "Cleaning up resources",
            file: #file,
            function: #function,
            line: #line
        )
    }

    private func saveApplicationState() {
        logger.debug(
            "Saving application state",
            file: #file,
            function: #function,
            line: #line
        )
    }

    private func checkForUpdates() {
        guard let url = URL(string: "https://api.github.com/repos/mpy/rBUM/releases/latest") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] _, _, _ in
            // Implementation moved to GitHubRelease.swift
        }.resume()
    }
    
    private func showUpdateAlert(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of rBUM (\(release.tagName)) is available."
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: release.htmlUrl)!)
        }
    }
    
    private func handleSleepState() {
        logger.info(
            "System entering sleep state",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Pause any active backup operations
        Task {
            await resticService.pauseAllOperations()
        }
    }
    
    private func handleWakeState() {
        logger.info(
            "System waking from sleep",
            file: #file,
            function: #function,
            line: #line
        )
        
        // Resume paused backup operations
        Task {
            await resticService.resumeAllOperations()
            // Check for updates after wake
            checkForUpdates()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                credentialsManager: credentialsManager,
                creationService: repositoryCreationService
            )
            .onAppear {
                logger.info(
                    "ContentView appeared",
                    file: #file,
                    function: #function,
                    line: #line
                )
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
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = LoggerFactory.createLogger(category: "AppDelegate")

    func applicationDidFinishLaunching(_: Notification) {
        logger.info(
            "Application did finish launching",
            file: #file,
            function: #function,
            line: #line
        )

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

    func applicationWillTerminate(_: Notification) {
        logger.info(
            "Application will terminate",
            file: #file,
            function: #function,
            line: #line
        )

        // Unregister observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        logger.info(
            "Application requested to terminate",
            file: #file,
            function: #function,
            line: #line
        )
        return .terminateNow
    }

    @objc private func handleSleepNotification(_: Notification) {
        logger.info(
            "System is going to sleep",
            file: #file,
            function: #function,
            line: #line
        )
        handleSleepState()
    }

    @objc private func handleWakeNotification(_: Notification) {
        logger.info(
            "System woke from sleep",
            file: #file,
            function: #function,
            line: #line
        )
        handleWakeState()
    }
}
