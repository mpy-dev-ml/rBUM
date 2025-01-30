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
                    TextField("Repository Path", text: $viewModel.path)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: viewModel.selectPath) {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                    }
                }
            } header: {
                Text("Repository Details")
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
        .fileImporter(
            isPresented: $viewModel.showFilePicker,
            allowedContentTypes: [.folder]
        ) { result in
            switch result {
            case .success(let url):
                viewModel.path = url.path()
            case .failure(let error):
                viewModel.state = .error(error)
                viewModel.showError = true
            }
        }
        .onChange(of: viewModel.state) { oldValue, newValue in
            if case .success = newValue {
                dismiss()
            }
        }
    }
}
