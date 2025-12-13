import CoreData
import Foundation

@objc(ClipboardItemEntity)
public class ClipboardItemEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var content: String
    @NSManaged public var type: String
    @NSManaged public var filename: String?
    @NSManaged public var timestamp: Date
    @NSManaged public var isPinned: Bool
    @NSManaged public var displayName: String?
    @NSManaged public var isTrashed: Bool
    @NSManaged public var tags: [String]?
    
    /// Convert to ClipboardItem for UI compatibility
    func toClipboardItem() -> ClipboardItem {
        return ClipboardItem(
            id: id,
            content: content,
            type: type,
            filename: filename,
            timestamp: timestamp,
            isPinned: isPinned,
            displayName: displayName,
            isTrashed: isTrashed,
            tags: tags
        )
    }
    
    /// Update from ClipboardItem
    func update(from item: ClipboardItem) {
        self.id = item.id
        self.content = item.content
        self.type = item.type
        self.filename = item.filename
        self.timestamp = item.timestamp
        self.isPinned = item.isPinned
        self.displayName = item.displayName
        self.isTrashed = item.isTrashed
        self.tags = item.tags
    }
    
    /// Create a new ClipboardItemEntity from ClipboardItem
    static func create(from item: ClipboardItem, in context: NSManagedObjectContext) -> ClipboardItemEntity {
        let entity = ClipboardItemEntity(context: context)
        entity.update(from: item)
        return entity
    }
}

extension ClipboardItemEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItemEntity> {
        return NSFetchRequest<ClipboardItemEntity>(entityName: "ClipboardItemEntity")
    }
    
    /// Fetch all items, sorted by timestamp
    static func fetchAll(in context: NSManagedObjectContext) throws -> [ClipboardItemEntity] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItemEntity.timestamp, ascending: false)]
        return try context.fetch(request)
    }
    
    /// Fetch a specific item by ID
    static func fetch(id: UUID, in context: NSManagedObjectContext) throws -> ClipboardItemEntity? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
