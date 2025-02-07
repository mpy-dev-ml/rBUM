//
//  BackupFlowUITests.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 03/02/2025.
//

import XCTest

final class BackupFlowUITests: XCTestCase {
    // MARK: - Properties

    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--use-mock-data"]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    private func navigateToBackupConfiguration() {
        // Select test repository
        let repositoryCell = app.cells["Test Repository"]
        XCTAssertTrue(repositoryCell.waitForExistence(timeout: 5))
        repositoryCell.tap()

        // Navigate to backup configuration
        app.buttons["Create Backup"].tap()
        XCTAssertTrue(app.navigationBars["New Backup"].exists)
    }

    private func fillBackupForm(name: String, paths: [String], excludePatterns: [String] = [], tags: [String] = []) {
        let nameField = app.textFields["Backup Name"]
        nameField.tap()
        nameField.typeText(name)

        // Add source paths
        for path in paths {
            app.buttons["Add Source"].tap()
            let dialog = app.sheets["Select Backup Source"]
            XCTAssertTrue(dialog.waitForExistence(timeout: 5))

            // Navigate to path
            let components = path.components(separatedBy: "/")
            for component in components {
                dialog.buttons[component].tap()
            }
            dialog.buttons["Select"].tap()
        }

        // Add exclude patterns
        for pattern in excludePatterns {
            app.buttons["Add Exclude Pattern"].tap()
            let patternField = app.textFields["Exclude Pattern"]
            patternField.tap()
            patternField.typeText(pattern)
            app.buttons["Add"].tap()
        }

        // Add tags
        for tag in tags {
            app.buttons["Add Tag"].tap()
            let tagField = app.textFields["Tag"]
            tagField.tap()
            tagField.typeText(tag)
            app.buttons["Add"].tap()
        }
    }

    // MARK: - Tests

    func testSuccessfulBackupCreation() throws {
        // Navigate to backup configuration
        navigateToBackupConfiguration()

        // Fill backup form
        fillBackupForm(
            name: "Documents Backup",
            paths: ["/Users/test/Documents"],
            excludePatterns: ["*.tmp", "*.cache"],
            tags: ["documents", "important"]
        )

        // Create backup
        app.buttons["Create Backup"].tap()

        // Verify success
        let successAlert = app.alerts["Backup Created"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(successAlert.staticTexts["Backup configuration created successfully."].exists)
        successAlert.buttons["OK"].tap()

        // Verify backup appears in list
        let backupCell = app.cells["Documents Backup"]
        XCTAssertTrue(backupCell.exists)
        XCTAssertTrue(backupCell.staticTexts["documents, important"].exists)
    }

    func testBackupExecution() throws {
        // Navigate to existing backup
        let backupCell = app.cells["Documents Backup"]
        XCTAssertTrue(backupCell.waitForExistence(timeout: 5))
        backupCell.tap()

        // Start backup
        app.buttons["Start Backup"].tap()

        // Verify progress view
        let progressView = app.progressIndicators["Backup Progress"]
        XCTAssertTrue(progressView.exists)

        // Verify progress updates
        let progressText = app.staticTexts["Backing up..."]
        XCTAssertTrue(progressText.waitForExistence(timeout: 5))

        // Wait for completion
        let completionText = app.staticTexts["Backup completed successfully"]
        XCTAssertTrue(completionText.waitForExistence(timeout: 30))

        // Verify snapshot appears in list
        let snapshotList = app.tables["Snapshots"]
        XCTAssertTrue(!snapshotList.cells.isEmpty)
    }

    func testBackupCancellation() throws {
        // Navigate to existing backup
        let backupCell = app.cells["Documents Backup"]
        XCTAssertTrue(backupCell.waitForExistence(timeout: 5))
        backupCell.tap()

        // Start backup
        app.buttons["Start Backup"].tap()

        // Wait for progress view
        let progressView = app.progressIndicators["Backup Progress"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 5))

        // Cancel backup
        app.buttons["Cancel Backup"].tap()

        // Verify cancellation dialog
        let alert = app.alerts["Cancel Backup"]
        XCTAssertTrue(alert.exists)
        XCTAssertTrue(alert.staticTexts["Are you sure you want to cancel the current backup?"].exists)

        // Confirm cancellation
        alert.buttons["Cancel Backup"].tap()

        // Verify cancellation
        let cancelledText = app.staticTexts["Backup cancelled"]
        XCTAssertTrue(cancelledText.waitForExistence(timeout: 5))
    }

    func testBackupScheduling() throws {
        // Navigate to backup configuration
        navigateToBackupConfiguration()

        // Fill basic backup form
        fillBackupForm(
            name: "Scheduled Backup",
            paths: ["/Users/test/Documents"]
        )

        // Enable scheduling
        app.switches["Enable Schedule"].tap()

        // Set schedule
        app.buttons["Schedule"].tap()
        let picker = app.pickers["Schedule Picker"]
        XCTAssertTrue(picker.exists)

        // Select daily schedule
        picker.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "Daily")
        picker.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "10:00 PM")

        app.buttons["Done"].tap()

        // Create backup
        app.buttons["Create Backup"].tap()

        // Verify schedule display
        let scheduleText = app.staticTexts["Daily at 10:00 PM"]
        XCTAssertTrue(scheduleText.exists)
    }

    func testBackupValidation() throws {
        // Navigate to backup configuration
        navigateToBackupConfiguration()

        // Test empty name validation
        app.buttons["Create Backup"].tap()
        let nameError = app.staticTexts["Backup name is required"]
        XCTAssertTrue(nameError.exists)

        // Test empty sources validation
        let nameField = app.textFields["Backup Name"]
        nameField.tap()
        nameField.typeText("Invalid Backup")

        app.buttons["Create Backup"].tap()
        let sourcesError = app.staticTexts["At least one backup source is required"]
        XCTAssertTrue(sourcesError.exists)
    }

    func testBackupProgress() throws {
        // Navigate to existing backup
        let backupCell = app.cells["Documents Backup"]
        XCTAssertTrue(backupCell.waitForExistence(timeout: 5))
        backupCell.tap()

        // Start backup
        app.buttons["Start Backup"].tap()

        // Verify progress elements
        let progressBar = app.progressIndicators["Backup Progress"]
        XCTAssertTrue(progressBar.exists)

        let currentFileText = app.staticTexts.matching(identifier: "Current File").firstMatch
        XCTAssertTrue(currentFileText.exists)

        let processedFilesText = app.staticTexts.matching(identifier: "Processed Files").firstMatch
        XCTAssertTrue(processedFilesText.exists)

        let processedBytesText = app.staticTexts.matching(identifier: "Processed Size").firstMatch
        XCTAssertTrue(processedBytesText.exists)

        // Wait for completion
        let completionText = app.staticTexts["Backup completed successfully"]
        XCTAssertTrue(completionText.waitForExistence(timeout: 30))
    }

    func testAccessibilityCompliance() throws {
        // Navigate to backup configuration
        navigateToBackupConfiguration()

        // Verify form accessibility
        XCTAssertTrue(app.textFields["Backup Name"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Add Source"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Add Exclude Pattern"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Add Tag"].isAccessibilityElement)
        XCTAssertTrue(app.switches["Enable Schedule"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Create Backup"].isAccessibilityElement)

        // Start a backup and verify progress accessibility
        fillBackupForm(name: "Accessibility Test", paths: ["/Users/test/Documents"])
        app.buttons["Create Backup"].tap()

        let backupCell = app.cells["Accessibility Test"]
        XCTAssertTrue(backupCell.waitForExistence(timeout: 5))
        backupCell.tap()

        app.buttons["Start Backup"].tap()

        XCTAssertTrue(app.progressIndicators["Backup Progress"].isAccessibilityElement)
        XCTAssertTrue(app.staticTexts["Current File"].isAccessibilityElement)
        XCTAssertTrue(app.staticTexts["Processed Files"].isAccessibilityElement)
        XCTAssertTrue(app.staticTexts["Processed Size"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Cancel Backup"].isAccessibilityElement)
    }
}
