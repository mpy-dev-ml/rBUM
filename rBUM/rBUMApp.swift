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
    private let fileSearchService: FileSearchServiceProtocol
    private let restoreService: RestoreServiceProtocol
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let dependencies = AppSetup.setupCoreDependencies()
        let securityServices = AppSetup.setupSecurityServices(dependencies)

        credentialsManager = AppSetup.setupCredentialsManager(
            dependencies: dependencies,
            keychainService: securityServices.keychainService
        )

        repositoryStorage = AppSetup.setupRepositoryStorage(dependencies.fileManager)

        resticService = AppSetup.setupResticService(
            dependencies: dependencies,
            securityServices: securityServices
        )

        repositoryCreationService = AppSetup.setupRepositoryCreationService(
            dependencies: dependencies,
            securityServices: securityServices
        )

        fileSearchService = AppSetup.setupFileSearchService(
            dependencies: dependencies,
            securityServices: securityServices,
            resticService: resticService,
            logger: logger
        )

        restoreService = AppSetup.setupRestoreService(
            dependencies: dependencies,
            securityServices: securityServices,
            resticService: resticService,
            logger: logger
        )

        logger.debug("App initialised", privacy: .public)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                credentialsManager: credentialsManager,
                repositoryStorage: repositoryStorage,
                resticService: resticService,
                repositoryCreationService: repositoryCreationService,
                fileSearchService: fileSearchService,
                restoreService: restoreService
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
}
