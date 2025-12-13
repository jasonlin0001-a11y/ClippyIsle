import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    // For preview purposes
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    init(inMemory: Bool = false) {
        // Create container with programmatic model
        let model = PersistenceController.createModel()
        container = NSPersistentCloudKitContainer(name: "ClippyIsle", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for CloudKit sharing
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Could not retrieve persistent store description")
            }
            
            // Enable persistent history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Configure CloudKit container options for sharing
            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.J894ABBU74.ClippyIsle")
            cloudKitContainerOptions.databaseScope = .private
            description.cloudKitContainerOptions = cloudKitContainerOptions
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Automatically merge changes from parent
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Sharing Support
    
    /// Check if an item can be shared
    func canShare(object: NSManagedObject) -> Bool {
        return container.canUpdateRecord(for: object.objectID)
    }
    
    /// Check if an item is already shared
    func isShared(object: NSManagedObject) -> Bool {
        return container.isShared(object: object.objectID)
    }
    
    /// Get existing share for an object
    func existingShare(for object: NSManagedObject) -> CKShare? {
        guard isShared(object: object) else { return nil }
        
        do {
            // Use Core Data to fetch the share record for this object
            let shares = try container.fetchShares(matching: [object.objectID])
            return shares.first
        } catch {
            print("Error fetching share: \(error)")
            return nil
        }
    }
    
    /// Create a new share for an object
    func createShare(for object: NSManagedObject, completion: @escaping (CKShare?, Error?) -> Void) {
        container.share([object], to: nil) { objectIDs, share, container, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            // Configure share properties
            share?[CKShare.SystemFieldKey.title] = "Clipboard Item"
            share?.publicPermission = .readOnly
            
            completion(share, nil)
        }
    }
    
    /// Delete a share for an object
    func deleteShare(for object: NSManagedObject, completion: @escaping (Error?) -> Void) {
        guard let share = existingShare(for: object) else {
            completion(nil)
            return
        }
        
        // Stop sharing by deleting the share record
        // This removes the share but keeps the object in the owner's database
        container.persistentStoreCoordinator.perform {
            do {
                let context = self.container.viewContext
                context.delete(share)
                try context.save()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
