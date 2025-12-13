import CoreData
import CloudKit

/// PersistenceController manages the Core Data stack with CloudKit integration
/// for ShareGroup and ClipboardItemEntity entities used in batch sharing feature.
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ShareGroupModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit sharing
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }
            
            // Enable persistent history tracking for CloudKit
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Configure CloudKit container options
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.shihchieh.clippyisle")
            description.cloudKitContainerOptions = cloudKitOptions
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // In production, handle this more gracefully
                print("❌ Core Data store failed to load: \(error), \(error.userInfo)")
            } else {
                print("✅ Core Data store loaded successfully")
            }
        }
        
        // Configure the view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Create sample data for previews
        let shareGroup = ShareGroup(context: viewContext)
        shareGroup.title = "Sample Share Group"
        shareGroup.createdAt = Date()
        
        let item1 = ClipboardItemEntity(context: viewContext)
        item1.id = UUID()
        item1.content = "Sample content 1"
        item1.type = "public.plain-text"
        item1.createdAt = Date()
        item1.isPinned = false
        item1.isTrashed = false
        
        let item2 = ClipboardItemEntity(context: viewContext)
        item2.id = UUID()
        item2.content = "Sample content 2"
        item2.type = "public.plain-text"
        item2.createdAt = Date()
        item2.isPinned = false
        item2.isTrashed = false
        
        shareGroup.addToItems(item1)
        shareGroup.addToItems(item2)
        
        do {
            try viewContext.save()
        } catch {
            print("❌ Failed to save preview data: \(error)")
        }
        
        return controller
    }()
    
    /// Save the view context
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Context saved successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Failed to save context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
