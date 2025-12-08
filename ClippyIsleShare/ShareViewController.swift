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
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                if let text = try await itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) as? String {
                    await saveContent(text, type: UTType.text.identifier)
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = try await itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL {
                    await saveContent(url.absoluteString, type: UTType.url.identifier)
                }
            } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                let data = try await itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier)
                let filename = saveFileDataToAppGroup(data: data, type: UTType.png.identifier)
                await saveContent("Image", type: UTType.png.identifier, filename: filename)
            } else {
                print("Unsupported type")
            }
        } catch {
             print("Share Error: \(error.localizedDescription)")
        }
        
        finish()
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
