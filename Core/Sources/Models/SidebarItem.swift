//
//  SidebarItem.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation

/// Represents a sidebar navigation item
public enum SidebarItem: String, CaseIterable, Identifiable {
    case repositories = "Repositories"
    case backups = "Backups"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    /// Icon name for the item
    public var iconName: String {
        switch self {
        case .repositories:
            return "folder"
        case .backups:
            return "arrow.clockwise"
        case .settings:
            return "gear"
        }
    }
}
