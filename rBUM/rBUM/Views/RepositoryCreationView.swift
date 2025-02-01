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
    
    init(creationService: RepositoryCreationServiceProtocol) {
        _viewModel = StateObject(wrappedValue: RepositoryCreationViewModel(creationService: creationService))
    }
    
    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $viewModel.mode) {
                    Text("Create New").tag(RepositoryCreationViewModel.Mode.create)
                    Text("Import Existing").tag(RepositoryCreationViewModel.Mode.import)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            
            Section {
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
            } header: {
                Text("Repository Details")
            } footer: {
                Text(viewModel.mode == .create 
                     ? "Choose where to create the new repository"
                     : "Select an existing repository to import")
                    .font(.caption)
            }
            
            Section {
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                
                if viewModel.mode == .create {
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
            } header: {
                Text("Security")
            } footer: {
                Text("This password will be securely stored in the macOS Keychain")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(viewModel.mode == .create ? "Create Repository" : "Import Repository")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.mode == .create ? "Create" : "Import") {
                    Task {
                        await viewModel.createOrImport()
                    }
                }
                .disabled(!viewModel.isValid)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            if case .success(let repository) = viewModel.state {
                Text("""
                    Repository successfully \(viewModel.mode == .create ? "created" : "imported")!
                    
                    Location: \(repository.path)
                    ID: \(repository.id)
                    """)
            }
        }
        .onChange(of: viewModel.state) { oldValue, newValue in
            if case .success = newValue {
                showSuccess = true
            }
        }
    }
}
