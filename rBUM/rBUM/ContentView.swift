//
//  ContentView.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem? = .repositories
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            switch selectedSidebarItem {
            case .repositories:
                RepositoryListView()
            case .backups:
                BackupListView()
            case .schedules:
                ScheduleListView()
            case .none:
                EmptyView()
            }
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case repositories = "Repositories"
    case backups = "Backups"
    case schedules = "Schedules"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .repositories:
            return "folder"
        case .backups:
            return "arrow.clockwise"
        case .schedules:
            return "calendar"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
        }
        .navigationTitle("rBUM")
    }
}

// Placeholder views - we'll implement these properly later
struct RepositoryListView: View {
    var body: some View {
        Text("Repository List")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BackupListView: View {
    var body: some View {
        Text("Backup List")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScheduleListView: View {
    var body: some View {
        Text("Schedule List")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
