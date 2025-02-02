//
//  RepositoryCreationView.swift
//  rBUM
//
//  Created by Matthew Yeager on 30/01/2025.
//

import SwiftUI

struct RepositoryCreationView: View {
    @StateObject private var viewModel: RepositoryCreationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSuccess = false
    
    init(creationService: RepositoryCreationServiceProtocol, credentialsManager: KeychainCredentialsManagerProtocol) {
        // Create the view model with dependencies
        let viewModel = RepositoryCreationViewModel(
            creationService: creationService,
            credentialsManager: credentialsManager
        )
        
        // Initialize the state object
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        formContent
            .formStyle(.grouped)
            .navigationTitle(viewModel.mode == .create ? "Create Repository" : "Import Repository")
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                successMessage
            }
            .onChange(of: viewModel.state) { oldState, newState in
                if case .success = newState {
                    showSuccess = true
                }
            }
    }
}

// MARK: - Subviews
private extension RepositoryCreationView {
    var formContent: some View {
        Form {
            Section { modePicker }
            
            Section {
                repositoryDetailsSection
            } header: {
                Text("Repository Details")
            } footer: {
                Text(viewModel.mode == .create 
                     ? "Choose where to create the new repository"
                     : "Select an existing repository to import")
                    .font(.caption)
            }
            
            Section {
                securitySection
            } header: {
                Text("Security")
            } footer: {
                Text("This password will be securely stored in the macOS Keychain")
                    .font(.caption)
            }
        }
    }
    
    var repositoryDetailsSection: some View {
        VStack {
            TextField("Repository Name", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                TextField("Repository Path", text: .constant(viewModel.path))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                
                Button(action: viewModel.selectPath) {
                    Label(viewModel.path.isEmpty ? "Select Location" : "Change Location", 
                          systemImage: "folder")
                }
            }
        }
    }
    
    var securitySection: some View {
        VStack {
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
            
            if viewModel.mode == .create {
                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.mode == .create ? "Create" : "Import") {
                    Task { await viewModel.createOrImport() }
                }
                .disabled(!viewModel.isValid)
            }
        }
    }
    
    var successMessage: Text? {
        if case .success(let repository) = viewModel.state {
            return Text("""
                Repository successfully \(viewModel.mode == .create ? "created" : "imported")!
                
                Location: \(repository.path)
                ID: \(repository.id)
                """)
        }
        return nil
    }
    
    var modePicker: some View {
        Picker("Mode", selection: $viewModel.mode) {
            ForEach(RepositoryCreationViewModel.Mode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Helper Extensions
private extension RepositoryCreationViewModel.Mode {
    var title: String {
        switch self {
        case .create:
            return "Create New"
        case .import:
            return "Import Existing"
        }
    }
}
