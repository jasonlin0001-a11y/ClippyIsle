import SwiftUI
import CoreData
import CloudKit

// MARK: - Example Integration for CloudKit Sharing

/// This file demonstrates how to integrate CloudKit Sharing into your existing ContentView.
/// This is a reference implementation - adapt it to your actual UI structure.

extension ContentView {
    
    // MARK: - State Variables for Sharing
    
    /// Add these state variables to your ContentView
    /*
    @State private var itemToShare: ClipboardItemEntity? = nil
    @State private var isShowingShareSheet = false
    */
    
    // MARK: - Sharing Methods
    
    /// Convert ClipboardItem (Codable) to ClipboardItemEntity (Core Data)
    /// This is needed because sharing only works with NSManagedObject
    func convertToEntity(_ item: ClipboardItem) -> ClipboardItemEntity? {
        let context = PersistenceController.shared.container.viewContext
        
        // Check if entity already exists
        if let existing = try? ClipboardItemEntity.fetch(id: item.id, in: context) {
            return existing
        }
        
        // Create new entity
        let entity = ClipboardItemEntity.create(from: item, in: context)
        
        // Save context
        do {
            try context.save()
            return entity
        } catch {
            print("Error saving entity: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Initiate sharing for a clipboard item
    /// Note: This example assumes you have itemToShare and isShowingShareSheet state variables
    /*
    func shareItem(_ item: ClipboardItem) {
        // Convert to Core Data entity
        guard let entity = convertToEntity(item) else {
            print("Failed to convert item to entity")
            return
        }
        
        // Check if item can be shared
        guard PersistenceController.shared.canShare(object: entity) else {
            print("Item cannot be shared")
            return
        }
        
        // Present share sheet
        itemToShare = entity
        isShowingShareSheet = true
    }
    */
    
    /// Check if an item is currently shared
    func isShared(_ item: ClipboardItem) -> Bool {
        guard let entity = try? ClipboardItemEntity.fetch(id: item.id, 
                                                          in: PersistenceController.shared.container.viewContext) else {
            return false
        }
        return PersistenceController.shared.isShared(object: entity)
    }
    
    /// Stop sharing an item
    func stopSharing(_ item: ClipboardItem) {
        guard let entity = try? ClipboardItemEntity.fetch(id: item.id,
                                                          in: PersistenceController.shared.container.viewContext) else {
            return
        }
        
        PersistenceController.shared.deleteShare(for: entity) { error in
            if let error = error {
                print("Error stopping share: \(error.localizedDescription)")
            } else {
                print("Successfully stopped sharing")
            }
        }
    }
}

// MARK: - UI Integration Examples

/// Example 1: Add Share Button to Item Context Menu
extension ContentView {
    
    /// Add this to your item's contextMenu
    func itemContextMenu(for item: ClipboardItem) -> some View {
        Group {
            // ... existing menu items ...
            
            Divider()
            
            // Share button
            if isShared(item) {
                Button(role: .destructive) {
                    stopSharing(item)
                } label: {
                    Label("Stop Sharing", systemImage: "person.crop.circle.badge.minus")
                }
                
                Button {
                    // Re-open share sheet to manage sharing
                    shareItem(item)
                } label: {
                    Label("Manage Share", systemImage: "person.crop.circle.badge.checkmark")
                }
            } else {
                Button {
                    shareItem(item)
                } label: {
                    Label("Share via iCloud", systemImage: "square.and.arrow.up.on.square")
                }
            }
        }
    }
}

/// Example 2: Add Share Button to Item Row
extension ContentView {
    
    func shareButton(for item: ClipboardItem) -> some View {
        Button {
            shareItem(item)
        } label: {
            Image(systemName: isShared(item) ? "person.2.fill" : "person.2")
                .foregroundColor(isShared(item) ? .blue : .gray)
                .font(.system(size: 16))
        }
        .buttonStyle(.borderless)
        .help(isShared(item) ? "Item is shared" : "Share this item")
    }
}

/// Example 3: Add to Main View Body
/// Note: This extension example assumes you have the required state variables
/*
extension ContentView {
    
    /// Add this modifier to your main view
    var sharingModifier: some View {
        // Only show sharing sheet when we have a valid entity
        if let itemToShare = itemToShare {
            EmptyView()
                .cloudSharing(
                    isPresented: $isShowingShareSheet,
                    item: itemToShare,
                    container: CKContainer(identifier: "iCloud.J894ABBU74.ClippyIsle")
                )
        }
    }
}
*/

// MARK: - Complete Example View

/// This shows a complete example of how the ContentView might look with sharing integrated
struct ContentViewWithSharing: View {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @State private var itemToShare: ClipboardItemEntity? = nil
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(clipboardManager.items.filter { !$0.isTrashed }) { item in
                    HStack {
                        // Item content
                        VStack(alignment: .leading) {
                            Text(item.displayName ?? item.content)
                                .lineLimit(1)
                            Text(item.timestamp.formatted())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Share indicator
                        if isShared(item) {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
                }
            }
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Share multiple items or show share options
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        // Conditional sharing sheet - only show when we have a valid entity
        if let itemToShare = itemToShare {
            EmptyView()
                .cloudSharing(
                    isPresented: $isShowingShareSheet,
                    item: itemToShare,
                    container: CKContainer(identifier: "iCloud.J894ABBU74.ClippyIsle")
                )
        }
    }
    
    // Helper methods
    func isShared(_ item: ClipboardItem) -> Bool {
        guard let entity = try? ClipboardItemEntity.fetch(id: item.id,
                                                          in: PersistenceController.shared.container.viewContext) else {
            return false
        }
        return PersistenceController.shared.isShared(object: entity)
    }
    
    func shareItem(_ item: ClipboardItem) {
        let context = PersistenceController.shared.container.viewContext
        
        if let existing = try? ClipboardItemEntity.fetch(id: item.id, in: context) {
            itemToShare = existing
            isShowingShareSheet = true
        } else {
            let newEntity = ClipboardItemEntity.create(from: item, in: context)
            do {
                try context.save()
                itemToShare = newEntity
                isShowingShareSheet = true
            } catch {
                print("Error creating entity for sharing: \(error)")
            }
        }
    }
    
    func itemContextMenu(for item: ClipboardItem) -> some View {
        Group {
            if isShared(item) {
                Button(role: .destructive) {
                    stopSharing(item)
                } label: {
                    Label("Stop Sharing", systemImage: "person.crop.circle.badge.minus")
                }
                
                Button {
                    shareItem(item)
                } label: {
                    Label("Manage Share", systemImage: "person.crop.circle.badge.checkmark")
                }
            } else {
                Button {
                    shareItem(item)
                } label: {
                    Label("Share via iCloud", systemImage: "square.and.arrow.up.on.square")
                }
            }
        }
    }
    
    func stopSharing(_ item: ClipboardItem) {
        guard let entity = try? ClipboardItemEntity.fetch(id: item.id,
                                                          in: PersistenceController.shared.container.viewContext) else {
            return
        }
        
        PersistenceController.shared.deleteShare(for: entity) { error in
            if let error = error {
                print("Error stopping share: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Migration Helper

/// Helper struct to migrate existing ClipboardItems to Core Data
struct CoreDataMigrationHelper {
    
    static func migrateAllItems(from clipboardManager: ClipboardManager) {
        let context = PersistenceController.shared.container.viewContext
        
        for item in clipboardManager.items {
            // Check if already migrated
            if (try? ClipboardItemEntity.fetch(id: item.id, in: context)) != nil {
                continue
            }
            
            // Create new entity
            _ = ClipboardItemEntity.create(from: item, in: context)
        }
        
        // Save all at once
        do {
            try context.save()
            print("✅ Successfully migrated \(clipboardManager.items.count) items to Core Data")
        } catch {
            print("❌ Migration failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    static func syncFromCoreData(to clipboardManager: ClipboardManager) {
        let context = PersistenceController.shared.container.viewContext
        
        do {
            let entities = try ClipboardItemEntity.fetchAll(in: context)
            let items = entities.map { $0.toClipboardItem() }
            
            // Update clipboard manager on main actor
            clipboardManager.items = items
            clipboardManager.sortAndSave(skipCloud: true)
        } catch {
            print("❌ Sync failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Usage Notes

/*
 To integrate CloudKit Sharing into your app:
 
 1. Add the state variables to your ContentView:
    @State private var itemToShare: ClipboardItemEntity? = nil
    @State private var isShowingShareSheet = false
 
 2. Add the cloudSharing modifier to your main view body:
    .cloudSharing(isPresented: $isShowingShareSheet, item: itemToShare ?? ..., container: ...)
 
 3. Add share buttons/menu items using the helper methods
 
 4. Optionally migrate existing items to Core Data:
    CoreDataMigrationHelper.migrateAllItems(from: clipboardManager)
 
 5. Test on physical devices with different iCloud accounts
 
 For more details, see CLOUDKIT_SHARING_GUIDE.md
 */
