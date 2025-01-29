//
//  rBUMApp.swift
//  rBUM
//
//  Created by Matthew Yeager on 29/01/2025.
//

import SwiftUI

@main
struct rBUMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
