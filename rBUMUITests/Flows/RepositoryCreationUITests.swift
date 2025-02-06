//
//  RepositoryCreationUITests.swift
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

final class RepositoryCreationUITests: XCTestCase {
    // MARK: - Properties
    
    private var app: XCUIApplication!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDown() async throws {
        app.terminate()
        app = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func navigateToRepositoryCreation() {
        app.buttons["Add Repository"].tap()
        XCTAssertTrue(app.navigationBars["New Repository"].exists)
    }
    
    private func fillRepositoryForm(name: String, description: String, path: String, password: String) {
        let nameField = app.textFields["Repository Name"]
        let descriptionField = app.textFields["Repository Description"]
        let pathButton = app.buttons["Select Path"]
        let passwordField = app.secureTextFields["Repository Password"]
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        
        nameField.tap()
        nameField.typeText(name)
        
        descriptionField.tap()
        descriptionField.typeText(description)
        
        pathButton.tap()
        // Handle path selection dialog
        let dialog = app.sheets["Select Repository Location"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        
        // Navigate to test directory
        let testPath = path.components(separatedBy: "/")
        for component in testPath {
            dialog.buttons[component].tap()
        }
        dialog.buttons["Select"].tap()
        
        passwordField.tap()
        passwordField.typeText(password)
        
        confirmPasswordField.tap()
        confirmPasswordField.typeText(password)
    }
    
    // MARK: - Tests
    
    func testSuccessfulRepositoryCreation() throws {
        // Navigate to repository creation
        navigateToRepositoryCreation()
        
        // Fill form with valid data
        fillRepositoryForm(
            name: "Test Repository",
            description: "Test Description",
            path: "/Users/test/Backups",
            password: "secure-password-123"
        )
        
        // Create repository
        app.buttons["Create Repository"].tap()
        
        // Verify success
        let successAlert = app.alerts["Repository Created"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(successAlert.staticTexts["Repository created successfully."].exists)
        successAlert.buttons["OK"].tap()
        
        // Verify navigation back to list
        XCTAssertTrue(app.navigationBars["Repositories"].exists)
        
        // Verify repository appears in list
        let repositoryCell = app.cells["Test Repository"]
        XCTAssertTrue(repositoryCell.exists)
        XCTAssertTrue(repositoryCell.staticTexts["Test Description"].exists)
    }
    
    func testRepositoryCreationValidation() throws {
        // Navigate to repository creation
        navigateToRepositoryCreation()
        
        // Test empty name validation
        app.buttons["Create Repository"].tap()
        let nameError = app.staticTexts["Repository name is required"]
        XCTAssertTrue(nameError.exists)
        
        // Test password mismatch
        fillRepositoryForm(
            name: "Test Repository",
            description: "Test Description",
            path: "/Users/test/Backups",
            password: "password1"
        )
        
        let confirmPasswordField = app.secureTextFields["Confirm Password"]
        confirmPasswordField.tap()
        confirmPasswordField.typeText("password2")
        
        app.buttons["Create Repository"].tap()
        let passwordError = app.staticTexts["Passwords do not match"]
        XCTAssertTrue(passwordError.exists)
    }
    
    func testRepositoryCreationCancellation() throws {
        // Navigate to repository creation
        navigateToRepositoryCreation()
        
        // Start filling form
        fillRepositoryForm(
            name: "Test Repository",
            description: "Test Description",
            path: "/Users/test/Backups",
            password: "secure-password-123"
        )
        
        // Cancel creation
        app.buttons["Cancel"].tap()
        
        // Verify confirmation dialog
        let alert = app.alerts["Discard Changes"]
        XCTAssertTrue(alert.exists)
        XCTAssertTrue(alert.staticTexts["Are you sure you want to discard your changes?"].exists)
        
        // Confirm cancellation
        alert.buttons["Discard"].tap()
        
        // Verify navigation back to list
        XCTAssertTrue(app.navigationBars["Repositories"].exists)
        
        // Verify repository does not appear in list
        let repositoryCell = app.cells["Test Repository"]
        XCTAssertFalse(repositoryCell.exists)
    }
    
    func testRepositoryPathSelection() throws {
        // Navigate to repository creation
        navigateToRepositoryCreation()
        
        // Tap path selection button
        app.buttons["Select Path"].tap()
        
        // Verify path selection dialog
        let dialog = app.sheets["Select Repository Location"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 5))
        
        // Test navigation
        dialog.buttons["Documents"].tap()
        dialog.buttons["New Folder"].tap()
        
        // Create folder dialog
        let folderAlert = app.alerts["New Folder"]
        XCTAssertTrue(folderAlert.exists)
        
        let folderNameField = folderAlert.textFields["Folder Name"]
        folderNameField.tap()
        folderNameField.typeText("Test Backups")
        folderAlert.buttons["Create"].tap()
        
        // Select created folder
        dialog.buttons["Test Backups"].tap()
        dialog.buttons["Select"].tap()
        
        // Verify path is displayed
        let pathLabel = app.staticTexts["/Users/test/Documents/Test Backups"]
        XCTAssertTrue(pathLabel.exists)
    }
    
    func testAccessibilityCompliance() throws {
        // Navigate to repository creation
        navigateToRepositoryCreation()
        
        // Verify accessibility labels
        XCTAssertTrue(app.textFields["Repository Name"].isAccessibilityElement)
        XCTAssertTrue(app.textFields["Repository Description"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Select Path"].isAccessibilityElement)
        XCTAssertTrue(app.secureTextFields["Repository Password"].isAccessibilityElement)
        XCTAssertTrue(app.secureTextFields["Confirm Password"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Create Repository"].isAccessibilityElement)
        
        // Verify accessibility hints
        XCTAssertNotNil(app.textFields["Repository Name"].value)
        XCTAssertNotNil(app.textFields["Repository Description"].value)
        XCTAssertNotNil(app.buttons["Select Path"].value)
        XCTAssertNotNil(app.secureTextFields["Repository Password"].value)
        XCTAssertNotNil(app.secureTextFields["Confirm Password"].value)
        
        // Verify keyboard navigation
        let elements = app.windows.firstMatch.children(matching: .any).allElements
        for element in elements where element.isAccessibilityElement {
            XCTAssertTrue(element.isEnabled)
        }
    }
}
