import CoreData

extension PersistenceController {
    /// Creates the Core Data model programmatically
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create ClipboardItemEntity
        let clipboardItemEntity = NSEntityDescription()
        clipboardItemEntity.name = "ClipboardItemEntity"
        clipboardItemEntity.managedObjectClassName = "ClipboardItemEntity"
        
        // Attributes
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let contentAttribute = NSAttributeDescription()
        contentAttribute.name = "content"
        contentAttribute.attributeType = .stringAttributeType
        contentAttribute.isOptional = false
        
        let typeAttribute = NSAttributeDescription()
        typeAttribute.name = "type"
        typeAttribute.attributeType = .stringAttributeType
        typeAttribute.isOptional = false
        
        let filenameAttribute = NSAttributeDescription()
        filenameAttribute.name = "filename"
        filenameAttribute.attributeType = .stringAttributeType
        filenameAttribute.isOptional = true
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        
        let isPinnedAttribute = NSAttributeDescription()
        isPinnedAttribute.name = "isPinned"
        isPinnedAttribute.attributeType = .booleanAttributeType
        isPinnedAttribute.defaultValue = false
        isPinnedAttribute.isOptional = false
        
        let displayNameAttribute = NSAttributeDescription()
        displayNameAttribute.name = "displayName"
        displayNameAttribute.attributeType = .stringAttributeType
        displayNameAttribute.isOptional = true
        
        let isTrashedAttribute = NSAttributeDescription()
        isTrashedAttribute.name = "isTrashed"
        isTrashedAttribute.attributeType = .booleanAttributeType
        isTrashedAttribute.defaultValue = false
        isTrashedAttribute.isOptional = false
        
        let tagsAttribute = NSAttributeDescription()
        tagsAttribute.name = "tags"
        tagsAttribute.attributeType = .transformableAttributeType
        tagsAttribute.valueTransformerName = NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue
        tagsAttribute.isOptional = true
        
        // Add attributes to entity
        clipboardItemEntity.properties = [
            idAttribute,
            contentAttribute,
            typeAttribute,
            filenameAttribute,
            timestampAttribute,
            isPinnedAttribute,
            displayNameAttribute,
            isTrashedAttribute,
            tagsAttribute
        ]
        
        // Add entities to model
        model.entities = [clipboardItemEntity]
        
        return model
    }
}
