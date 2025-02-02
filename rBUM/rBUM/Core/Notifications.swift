//
//  Notifications.swift
//  rBUM
//
//  Created by Matthew Yeager on 01/02/2025.
//

import Foundation

extension Notification.Name {
    /// Posted when configuration changes
    static let configurationDidChange = Notification.Name("configurationDidChange")
    
    /// Posted when configuration storage encounters an error
    static let configurationStorageError = Notification.Name("configurationStorageError")
}
