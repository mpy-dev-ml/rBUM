//
//  BackupTag.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
import Foundation
import Core

/// Protocol defining backup tag management functionality
public protocol BackupTagManagerProtocol {
    /// Create a new tag
    func createTag(name: String, description: String?) throws -> BackupTag
    
    /// Delete an existing tag
    func deleteTag(_ tag: BackupTag) throws
    
    /// Update an existing tag
    func updateTag(_ tag: BackupTag, name: String, description: String?) throws
    
    /// Get all tags
    func getAllTags() throws -> [BackupTag]
    
    /// Associate a tag with a backup
    func associateTag(_ tag: BackupTag, withBackupId backupId: String) throws
    
    /// Remove tag association from a backup
    func removeTag(_ tag: BackupTag, fromBackupId backupId: String) throws
    
    /// Get tags for a backup
    func getTags(forBackupId backupId: String) throws -> [BackupTag]
}

/// Represents a backup tag for organizing and filtering backups
public struct BackupTag: Codable, Identifiable, Equatable {
    /// Unique identifier for the tag
    public let id: String
    
    /// Name of the tag
    public var name: String
    
    /// Optional description of the tag's purpose
    public var description: String?
    
    /// Creation date of the tag
    public let createdAt: Date
    
    /// Last modification date of the tag
    public var modifiedAt: Date
    
    /// Initialize a new tag
    public init(id: String = UUID().uuidString,
                name: String,
                description: String? = nil,
                createdAt: Date = Date(),
                modifiedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Manager for handling backup tags
public final class BackupTagManager: BackupTagManagerProtocol {
    // MARK: - Properties
    
    private let notificationCenter: NotificationCenter
    private let dateProvider: DateProviderProtocol
    private let fileManager: FileManagerProtocol
    private let tagsDirectory: String
    private var tags: [BackupTag] = []
    private var tagAssociations: [String: Set<String>] = [:] // [backupId: Set<tagId>]
    
    // MARK: - Initialization
    
    public init(notificationCenter: NotificationCenter,
                dateProvider: DateProviderProtocol,
                fileManager: FileManagerProtocol,
                tagsDirectory: String = "tags") {
        self.notificationCenter = notificationCenter
        self.dateProvider = dateProvider
        self.fileManager = fileManager
        self.tagsDirectory = tagsDirectory
        loadTags()
    }
    
    // MARK: - Private Methods
    
    private func loadTags() {
        // Load tags from storage
        // This is a stub - implement actual persistence
    }
    
    private func saveTags() throws {
        // Save tags to storage
        // This is a stub - implement actual persistence
    }
    
    private func validateTagName(_ name: String) throws {
        guard !name.isEmpty else {
            throw BackupTagError.invalidName
        }
    }
    
    // MARK: - BackupTagManagerProtocol
    
    public func createTag(name: String, description: String? = nil) throws -> BackupTag {
        try validateTagName(name)
        
        let tag = BackupTag(
            name: name,
            description: description,
            createdAt: dateProvider.now(),
            modifiedAt: dateProvider.now()
        )
        
        tags.append(tag)
        try saveTags()
        
        notificationCenter.post(name: .backupTagsChanged, object: nil)
        return tag
    }
    
    public func deleteTag(_ tag: BackupTag) throws {
        guard let index = tags.firstIndex(where: { $0.id == tag.id }) else {
            throw BackupTagError.tagNotFound
        }
        
        tags.remove(at: index)
        
        // Remove all associations for this tag
        for backupId in tagAssociations.keys {
            tagAssociations[backupId]?.remove(tag.id)
        }
        
        try saveTags()
        notificationCenter.post(name: .tagDeleted, object: tag)
    }
    
    public func updateTag(_ tag: BackupTag, name: String, description: String?) throws {
        try validateTagName(name)
        
        guard let index = tags.firstIndex(where: { $0.id == tag.id }) else {
            throw BackupTagError.tagNotFound
        }
        
        var updatedTag = tag
        updatedTag.name = name
        updatedTag.description = description
        updatedTag.modifiedAt = dateProvider.now()
        
        tags[index] = updatedTag
        try saveTags()
        
        notificationCenter.post(name: .backupTagsChanged, object: nil)
    }
    
    public func getAllTags() throws -> [BackupTag] {
        return tags
    }
    
    public func associateTag(_ tag: BackupTag, withBackupId backupId: String) throws {
        guard tags.contains(where: { $0.id == tag.id }) else {
            throw BackupTagError.tagNotFound
        }
        
        var associations = tagAssociations[backupId] ?? Set()
        associations.insert(tag.id)
        tagAssociations[backupId] = associations
        
        try saveTags()
        notificationCenter.post(name: .tagAssociated, object: (tag, backupId))
    }
    
    public func removeTag(_ tag: BackupTag, fromBackupId backupId: String) throws {
        guard tags.contains(where: { $0.id == tag.id }) else {
            throw BackupTagError.tagNotFound
        }
        
        tagAssociations[backupId]?.remove(tag.id)
        try saveTags()
        
        notificationCenter.post(name: .tagRemoved, object: (tag, backupId))
    }
    
    public func getTags(forBackupId backupId: String) throws -> [BackupTag] {
        let tagIds = tagAssociations[backupId] ?? Set()
        return tags.filter { tagIds.contains($0.id) }
    }
}

// MARK: - Errors

/// Errors that can occur during backup tag operations
public enum BackupTagError: Error {
    case invalidName
    case tagNotFound
    case storageError
}

// MARK: - Notifications

extension Notification.Name {
    static let tagCreated = Notification.Name("tagCreated")
    static let tagDeleted = Notification.Name("tagDeleted")
    static let tagUpdated = Notification.Name("tagUpdated")
    static let tagAssociated = Notification.Name("tagAssociated")
    static let tagRemoved = Notification.Name("tagRemoved")
    static let backupTagsChanged = Notification.Name("backupTagsChanged")
}
