import Foundation
import CoreData
import CloudKit
import UIKit

/// ShareGroupManager handles creating share groups for batch sharing
/// and importing shared items into the local library.
class ShareGroupManager: ObservableObject {
    static let shared = ShareGroupManager()
    
    private let persistenceController: PersistenceController
    private let clipboardManager: ClipboardManager
    
    @Published var isProcessing = false
    @Published var lastError: Error?
    
    init(persistenceController: PersistenceController = .shared,
         clipboardManager: ClipboardManager = .shared) {
        self.persistenceController = persistenceController
        self.clipboardManager = clipboardManager
    }
    
    // MARK: - Sender Side: Create Share Group
    
    /// Creates a new ShareGroup with copies of the selected ClipboardItems.
    /// This creates new Core Data entities to avoid affecting the user's original data.
    ///
    /// - Parameter items: Array of ClipboardItems to include in the share group
    /// - Parameter title: Title for the share group (will be localized if empty)
    /// - Returns: The newly created ShareGroup entity
    func createShareGroup(with items: [ClipboardItem], title: String) throws -> ShareGroup {
        let context = persistenceController.container.viewContext
        
        // Use localized default if title is empty
        let finalTitle = title.isEmpty ? String(localized: "Shared Items") : title
        
        // Create the ShareGroup
        let shareGroup = ShareGroup(context: context)
        shareGroup.title = finalTitle
        shareGroup.createdAt = Date()
        
        // Create copies of the ClipboardItems as ClipboardItemEntity objects
        for item in items {
            let itemEntity = ClipboardItemEntity(context: context)
            itemEntity.id = UUID() // New UUID to avoid conflicts
            itemEntity.content = item.content
            itemEntity.type = item.type
            itemEntity.createdAt = item.timestamp
            itemEntity.isPinned = item.isPinned
            itemEntity.isTrashed = false // Don't share trashed items
            itemEntity.displayName = item.displayName
            
            // Copy tags if present
            if let tags = item.tags {
                itemEntity.tags = tags
            }
            
            // Note: Filename/file data is not copied to avoid large data transfers
            // Only text content is shared
            
            shareGroup.addToItems(itemEntity)
        }
        
        // Save the context
        try context.save()
        print("✅ Created ShareGroup '\(title)' with \(items.count) items")
        
        return shareGroup
    }
    
    /// Presents the UICloudSharingController to share the given ShareGroup
    ///
    /// - Parameters:
    ///   - shareGroup: The ShareGroup to share
    ///   - viewController: The presenting view controller
    func shareGroup(_ shareGroup: ShareGroup, from viewController: UIViewController) async throws {
        guard let managedObjectContext = shareGroup.managedObjectContext else {
            throw ShareGroupError.noContext
        }
        
        // Get the persistent store coordinator and container
        guard let persistentStore = managedObjectContext.persistentStoreCoordinator?.persistentStores.first else {
            throw ShareGroupError.noPersistentStore
        }
        
        let container = persistenceController.container
        
        // Check if the object is already shared
        let existingShare: CKShare?
        if let shares = try? container.fetchShares(matching: [shareGroup.objectID]),
           let share = shares.first {
            existingShare = share
        } else {
            existingShare = nil
        }
        
        // Create or get the share
        let share: CKShare
        if let existing = existingShare {
            share = existing
        } else {
            // Create a new share
            let (_, newShare, _) = try await container.share([shareGroup], to: persistentStore)
            share = newShare
        }
        
        // Configure share permissions
        share[CKShare.SystemFieldKey.title] = shareGroup.title
        
        // Create the UICloudSharingController
        let sharingController = UICloudSharingController(share: share, container: container.cloudKitContainer)
        
        // Present the controller
        await MainActor.run {
            viewController.present(sharingController, animated: true)
        }
    }
    
    // MARK: - Receiver Side: Import Shared Items
    
    /// Imports shared items from a ShareGroup into the local ClipboardManager.
    /// Creates deep copies with new UUIDs to avoid conflicts.
    ///
    /// - Parameter group: The shared ShareGroup to import from
    /// - Returns: The number of items imported
    @discardableResult
    func importSharedItems(from group: ShareGroup) async throws -> Int {
        await MainActor.run {
            isProcessing = true
        }
        defer { 
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        guard let items = group.items?.allObjects as? [ClipboardItemEntity] else {
            throw ShareGroupError.noItemsInGroup
        }
        
        var importedCount = 0
        
        // Import each item into the ClipboardManager
        for itemEntity in items {
            // Create a new ClipboardItem (struct) from the entity
            let newItem = ClipboardItem(
                id: UUID(), // New UUID for the local copy
                content: itemEntity.content ?? "",
                type: itemEntity.type ?? "public.plain-text",
                filename: nil, // Don't copy filename
                timestamp: Date(), // Use current timestamp
                isPinned: false, // Don't copy pinned status
                displayName: itemEntity.displayName,
                isTrashed: false, // Import as active item
                tags: itemEntity.tags as? [String],
                fileData: nil // Don't copy file data
            )
            
            // Add to the clipboard manager
            await MainActor.run {
                clipboardManager.items.insert(newItem, at: 0)
            }
            
            importedCount += 1
        }
        
        // Save the changes
        await MainActor.run {
            clipboardManager.sortAndSave()
        }
        
        print("✅ Imported \(importedCount) items from ShareGroup '\(group.title ?? "Untitled")'")
        
        return importedCount
    }
    
    // MARK: - Cleanup: Leave Share
    
    /// Leaves the share and purges the shared data from the device.
    /// The user keeps their local imported copies.
    ///
    /// - Parameter shareGroup: The ShareGroup to leave
    func leaveShare(_ shareGroup: ShareGroup) async throws {
        guard let managedObjectContext = shareGroup.managedObjectContext else {
            throw ShareGroupError.noContext
        }
        
        let container = persistenceController.container
        
        // Fetch the share
        let shares = try container.fetchShares(matching: [shareGroup.objectID])
        guard let share = shares.first else {
            throw ShareGroupError.shareNotFound
        }
        
        // Purge the share
        try await container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID)
        
        print("✅ Left share and purged data for ShareGroup '\(shareGroup.title ?? "Untitled")'")
    }
    
    // MARK: - Fetch Share Groups
    
    /// Fetches all ShareGroups (both owned and shared with the user)
    func fetchShareGroups() async -> [ShareGroup] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<ShareGroup> = ShareGroup.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ShareGroup.createdAt, ascending: false)]
        
        return await context.perform {
            do {
                let groups = try context.fetch(fetchRequest)
                print("✅ Fetched \(groups.count) share groups")
                return groups
            } catch {
                print("❌ Failed to fetch share groups: \(error)")
                Task { @MainActor in
                    self.lastError = error
                }
                return []
            }
        }
    }
    
    /// Fetches only the incoming shared groups (shared by others)
    func fetchIncomingSharedGroups() async -> [ShareGroup] {
        let allGroups = await fetchShareGroups()
        let container = persistenceController.container
        
        // Move the filtering to a background queue
        return await Task.detached {
            let sharedGroups = allGroups.filter { group in
                if let shares = try? container.fetchShares(matching: [group.objectID]),
                   let share = shares.first {
                    // Check if current user is not the owner
                    return share.owner != CKCurrentUserDefaultName
                }
                return false
            }
            
            print("✅ Fetched \(sharedGroups.count) incoming shared groups")
            return sharedGroups
        }.value
    }
    
    /// Deletes a ShareGroup from Core Data
    func deleteShareGroup(_ shareGroup: ShareGroup) throws {
        guard let context = shareGroup.managedObjectContext else {
            throw ShareGroupError.noContext
        }
        
        context.delete(shareGroup)
        try context.save()
        print("✅ Deleted ShareGroup '\(shareGroup.title ?? "Untitled")'")
    }
}

// MARK: - Errors

enum ShareGroupError: LocalizedError {
    case noContext
    case noPersistentStore
    case noItemsInGroup
    case shareNotFound
    
    var errorDescription: String? {
        switch self {
        case .noContext:
            return "Managed object context not available"
        case .noPersistentStore:
            return "Persistent store not available"
        case .noItemsInGroup:
            return "No items found in share group"
        case .shareNotFound:
            return "Share not found for this group"
        }
    }
}
