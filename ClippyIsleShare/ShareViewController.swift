import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGray6
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            finish()
            return
        }
        
        Task {
            await handle(itemProvider: itemProvider)
        }
    }
    
    private func handle(itemProvider: NSItemProvider) async {
        do {
            // Check for JSON files first (for import functionality)
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
                let data = try await itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.json.identifier)
                importJSONData(data)
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                // Handle file URLs (could be .json files)
                if let url = try await itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) as? URL {
                    if url.pathExtension.lowercased() == "json" {
                        let data = try Data(contentsOf: url)
                        importJSONData(data)
                    } else {
                        saveContent(url.absoluteString, type: UTType.url.identifier)
                    }
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                // Try to load as URL type first since URLs shared from apps often conform to this
                if let url = try await itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL {
                    saveContent(url.absoluteString, type: UTType.url.identifier)
                } else {
                    // Fallback: if URL type exists but can't be loaded as URL, try text
                    if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
                       let text = try await itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) as? String {
                        // Detect if text is actually a URL
                        let detectedType = isValidURL(text) ? UTType.url.identifier : UTType.text.identifier
                        saveContent(text, type: detectedType)
                    }
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                if let text = try await itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) as? String {
                    // Detect if text is actually a URL
                    let detectedType = isValidURL(text) ? UTType.url.identifier : UTType.text.identifier
                    saveContent(text, type: detectedType)
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let data = try await itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier)
                let filename = saveFileDataToAppGroup(data: data, type: UTType.png.identifier)
                saveContent("Image", type: UTType.png.identifier, filename: filename)
            } else {
                print("Unsupported type")
            }
        } catch {
             print("Share Error: \(error.localizedDescription)")
        }
        
        finish()
    }
    
    // Helper function to validate if a string is a URL
    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        let lowercased = string.lowercased()
        return (lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://")) && url.host != nil
    }
    
    @MainActor
    private func saveContent(_ content: String, type: String, filename: String? = nil) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Share Extension: Failed to get UserDefaults for App Group.")
            return
        }
        
        var items: [ClipboardItem] = []
        if let data = defaults.data(forKey: "clippedItems"),
           let decodedItems = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            items = decodedItems
        }
        
        // 【重點修正】使用新的初始化方法來建立項目
        let newItem = ClipboardItem(content: content, type: type, filename: filename)
        items.insert(newItem, at: 0)
        
        items.sort { item1, item2 in
            if item1.isPinned != item2.isPinned { return item1.isPinned && !item2.isPinned }
            if item1.isPinned { return item1.timestamp < item2.timestamp }
            else { return item1.timestamp > item2.timestamp }
        }

        if let encodedData = try? JSONEncoder().encode(items) {
            defaults.set(encodedData, forKey: "clippedItems")
            print("✅ Share Extension: Saved new item.")
        }
        
        // Also add to pending notifications for Message Center
        addToPendingNotifications([newItem], source: "appShare", defaults: defaults)
    }
    
    // Import JSON data (ClippyIsle backup file)
    @MainActor
    private func importJSONData(_ data: Data) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ Share Extension: Failed to get UserDefaults for App Group.")
            return
        }
        
        do {
            // Decode imported items using shared ExportableClipboardItem
            let importedItems = try JSONDecoder().decode([ExportableClipboardItem].self, from: data)
            
            // Load existing items
            var existingItems: [ClipboardItem] = []
            if let existingData = defaults.data(forKey: "clippedItems") {
                do {
                    let decodedItems = try JSONDecoder().decode([ClipboardItem].self, from: existingData)
                    existingItems = decodedItems
                } catch {
                    print("⚠️ Share Extension: Failed to decode existing items, starting fresh: \(error.localizedDescription)")
                    // Continue with empty array if existing data is corrupted
                }
            }
            
            let existingIDs = Set(existingItems.map { $0.id })
            var newItemsCount = 0
            
            // Add new items that don't already exist
            for importedItem in importedItems {
                guard !existingIDs.contains(importedItem.id) else { continue }
                
                var newItem = ClipboardItem(
                    id: importedItem.id,
                    content: importedItem.content,
                    type: importedItem.type,
                    filename: importedItem.filename,
                    timestamp: importedItem.timestamp,
                    isPinned: importedItem.isPinned,
                    displayName: importedItem.displayName,
                    isTrashed: importedItem.isTrashed,
                    tags: importedItem.tags,
                    fileData: nil
                )
                
                // Save file data if present
                if let fileData = importedItem.fileData {
                    if let newFilename = saveFileDataToAppGroup(data: fileData, type: importedItem.type) {
                        newItem.filename = newFilename
                    } else {
                        print("⚠️ Share Extension: Failed to save file data for item \(importedItem.id), continuing without file")
                        // Continue without file data rather than failing entire import
                    }
                }
                
                existingItems.append(newItem)
                newItemsCount += 1
            }
            
            // Sort and save
            existingItems.sort { item1, item2 in
                if item1.isPinned != item2.isPinned { return item1.isPinned && !item2.isPinned }
                return item1.timestamp > item2.timestamp
            }
            
            let encodedData = try JSONEncoder().encode(existingItems)
            defaults.set(encodedData, forKey: "clippedItems")
            print("✅ Share Extension: Imported \(newItemsCount) new items from JSON.")
            
            // Also add imported items to pending notifications for Message Center
            let importedClipboardItems = importedItems.map { importedItem in
                ClipboardItem(
                    id: importedItem.id,
                    content: importedItem.content,
                    type: importedItem.type,
                    filename: importedItem.filename,
                    timestamp: importedItem.timestamp,
                    isPinned: importedItem.isPinned,
                    displayName: importedItem.displayName,
                    isTrashed: importedItem.isTrashed,
                    tags: importedItem.tags,
                    fileData: nil
                )
            }
            addToPendingNotifications(importedClipboardItems, source: "appShare", defaults: defaults)
        } catch {
            print("❌ Share Extension: Failed to import JSON data: \(error.localizedDescription)")
        }
    }
    
    // Add items to pending notifications for Message Center
    private func addToPendingNotifications(_ items: [ClipboardItem], source: String, defaults: UserDefaults) {
        // Use a simple structure that can be decoded by the main app
        struct PendingNotification: Codable {
            var id: UUID
            var items: [ClipboardItem]
            var timestamp: Date
            var source: String
        }
        
        var pendingNotifications: [PendingNotification] = []
        
        // Load existing pending notifications
        if let data = defaults.data(forKey: "pendingNotifications"),
           let decoded = try? JSONDecoder().decode([PendingNotification].self, from: data) {
            pendingNotifications = decoded
        }
        
        // Add new notification
        let newNotification = PendingNotification(
            id: UUID(),
            items: items,
            timestamp: Date(),
            source: source
        )
        pendingNotifications.insert(newNotification, at: 0)
        
        // Save back
        if let encoded = try? JSONEncoder().encode(pendingNotifications) {
            defaults.set(encoded, forKey: "pendingNotifications")
            print("✅ Share Extension: Added notification with \(items.count) item(s) to pending notifications.")
        }
    }
    
    private func finish() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}

extension NSItemProvider {
    func loadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = self.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    let noDataError = NSError(domain: "NSItemProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data was returned for the requested type."])
                    continuation.resume(throwing: noDataError)
                }
            }
        }
    }
}
