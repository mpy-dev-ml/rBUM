import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            BackupSettingsView()
                .tabItem {
                    Label("Backup", systemImage: "arrow.clockwise")
                }

            SecuritySettingsView()
                .tabItem {
                    Label("Security", systemImage: "lock")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General Settings")
                .font(.title2)
        }
        .padding()
    }
}

struct BackupSettingsView: View {
    var body: some View {
        Form {
            Text("Backup Settings")
                .font(.title2)
        }
        .padding()
    }
}

struct SecuritySettingsView: View {
    var body: some View {
        Form {
            Text("Security Settings")
                .font(.title2)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
