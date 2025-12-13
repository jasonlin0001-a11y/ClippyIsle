import Foundation
@preconcurrency import CoreData
import CloudKit
import UIKit
import Combine

/// ShareGroupManager handles creating share groups for batch sharing
/// and importing shared items into the local library.
@MainActor
class ShareGroupManager: ObservableObject {
    static let shared = ShareGroupManager()
    
    private let persistenceController: PersistenceController
    private let clipboardManager: ClipboardManager
    
    @Published var isProcessing = false
    @Published var lastError: Error?
    
    init(persistenceController: PersistenceController? = nil,
         clipboardManager: ClipboardManager? = nil) {
        if let persistenceController = persistenceController {
            self.persistenceController = persistenceController
        } else {
            self.persistenceController = PersistenceController.shared
        }
        
        if let clipboardManager = clipboardManager {
            self.clipboardManager = clipboardManager
        } else {
            self.clipboardManager = ClipboardManager.shared
        }
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
    ///   - delegate: The UICloudSharingControllerDelegate
    func shareGroup(_ shareGroup: ShareGroup, from viewController: UIViewController, delegate: UICloudSharingControllerDelegate? = nil) async throws {
        print("🔄 Starting shareGroup process...")
        
        // Ensure we're working with the main context's version of the object
        let objectID = shareGroup.objectID
        let context = persistenceController.container.viewContext
        
        print("📍 Getting object from context with ID: \(objectID)")
        guard let groupToShare = try? context.existingObject(with: objectID) as? ShareGroup else {
            let error = NSError(domain: "ShareGroupManager", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Cannot find the share group. Please try again."])
            print("❌ Error: \(error.localizedDescription)")
            throw error
        }
        
        print("✅ Found share group: \(groupToShare.title ?? "Untitled")")
        
        let container = persistenceController.container
        
        // Check if already shared on a background thread
        print("🔍 Checking for existing share...")
        let existingShare: CKShare? = await Task.detached {
            if let shares = try? container.fetchShares(matching: [objectID]),
               let share = shares[objectID] {
                return share
            }
            return nil
        }.value
        
        // Create or get the share on main thread
        let share: CKShare
        if let existing = existingShare {
            print("✅ Using existing share")
            share = existing
        } else {
            print("🆕 Creating new share...")
            // Save context before sharing to ensure object is persisted
            try await context.perform {
                if context.hasChanges {
                    print("💾 Saving context changes...")
                    try context.save()
                }
            }
            
            // Create a new share - must be done on main thread
            print("⚙️ Calling container.share()...")
            do {
                let (_, newShare, _) = try await container.share([groupToShare], to: nil)
                share = newShare
                print("✅ Share created successfully")
            } catch {
                print("❌ Failed to create share: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ Error code: \(nsError.code), domain: \(nsError.domain)")
                    print("❌ User info: \(nsError.userInfo)")
                }
                throw NSError(domain: "ShareGroupManager", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "CloudKit sharing failed: \(error.localizedDescription). Make sure you're signed in to iCloud and have an active internet connection."])
            }
            
            // Save the context again after creating the share
            try await context.perform {
                if context.hasChanges {
                    print("💾 Saving context after share creation...")
                    try context.save()
                }
            }
        }
        
        // Configure share permissions on main thread
        await MainActor.run {
            share[CKShare.SystemFieldKey.title] = groupToShare.title
        }
        
        // Create the UICloudSharingController
        print("📱 Creating UICloudSharingController...")
        let ckContainer = CKContainer(identifier: "iCloud.J894ABBU74.ClippyIsle")
        let sharingController = UICloudSharingController(share: share, container: ckContainer)
        
        // Set delegate if provided
        if let delegate = delegate {
            sharingController.delegate = delegate
        }
        
        // Present the controller on main thread
        print("🎬 Presenting share controller...")
        await MainActor.run {
            viewController.present(sharingController, animated: true)
        }
        
        print("✅ Share controller presented successfully")
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
        guard let share = shares[shareGroup.objectID] else {
            throw ShareGroupError.shareNotFound
        }
        
        // Get the persistent store
        guard let store = managedObjectContext.persistentStoreCoordinator?.persistentStores.first else {
            throw ShareGroupError.noContext
        }
        
        // Purge the share
        try await container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store)
        
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
        
        // Extract objectIDs to pass to detached task (objectIDs are Sendable)
        let groupObjectIDs = allGroups.map { $0.objectID }
        
        // Filter in a background context
        let sharedObjectIDs = await Task.detached {
            let sharedIDs = groupObjectIDs.filter { objectID in
                if let shares = try? container.fetchShares(matching: [objectID]),
                   let share = shares[objectID] {
                    // Check if current user is not the owner
                    return share.owner.userIdentity.userRecordID?.recordName != CKCurrentUserDefaultName
                }
                return false
            }
            return sharedIDs
        }.value
        
        // Filter the original array based on the objectIDs
        let sharedGroups = allGroups.filter { group in
            sharedObjectIDs.contains(group.objectID)
        }
        
        print("✅ Fetched \(sharedGroups.count) incoming shared groups")
        return sharedGroups
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
    case noItemsInGroup
    case shareNotFound
    
    var errorDescription: String? {
        switch self {
        case .noContext:
            return "Managed object context not available"
        case .noItemsInGroup:
            return "No items found in share group"
        case .shareNotFound:
            return "Share not found for this group"
        }
    }
}
