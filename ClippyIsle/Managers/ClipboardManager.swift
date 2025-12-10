import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import Combine
import PDFKit
import UIKit

// MARK: - Clipboard Manager
@MainActor
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var items: [ClipboardItem] = []
    @Published var activity: Activity<ClippyIsleAttributes>? = nil
    @Published var isLiveActivityOn: Bool
    
    let userDefaults: UserDefaults
    let fileManager = FileManager.default
    private var didInitializeSuccessfully = false
    @Published var dataLoadError: Error? = nil
    let cloudKitManager = CloudKitManager.shared

    private let currentDataVersion = 3
    
    // Legacy structures for migration
    struct ClipboardItemV1: Codable {
        var id: UUID; var content: String; var timestamp: Date; var type: String; var isPinned: Bool; var isTrashed: Bool; var filename: String?
    }
    struct ClipboardItemV2: Codable {
        var id: UUID; var content: String; var type: String; var filename: String?; var timestamp: Date; var isPinned: Bool; var displayName: String?; var isTrashed: Bool
    }
    // Note: ExportableClipboardItem is now defined in SharedModels.swift

    public init() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ 致命警告: 無法初始化 App Group UserDefaults。")
            self.userDefaults = UserDefaults.standard; self.isLiveActivityOn = false; self.didInitializeSuccessfully = false
            self.dataLoadError = NSError(domain: "ClipboardManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "無法初始化 App Group"])
            return
        }
        self.userDefaults = defaults
        self.didInitializeSuccessfully = true
        isLiveActivityOn = UserDefaults.standard.bool(forKey: "isLiveActivityOn")
        
        let standardDefaults = UserDefaults.standard
        standardDefaults.register(defaults: ["showSpeechSubtitles": true, "askToAddFromClipboard": true, "speechRate": 0.5, "iCloudSyncEnabled": true])
    }
    
    public func initializeData() {
        guard didInitializeSuccessfully else { return }
        loadItems(); cleanupItems()
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { Task { await performCloudSync() } }
    }
    
    func performCloudSync() async {
        let syncedItems = await cloudKitManager.sync(localItems: self.items)
        await MainActor.run { self.items = syncedItems; self.sortAndSave(skipCloud: true) }
    }
    
    func hardResetData() {
        items = []
        userDefaults.removeObject(forKey: "clippedItems"); userDefaults.removeObject(forKey: "clippedItems_corrupted_backup"); userDefaults.removeObject(forKey: "dataModelVersion"); userDefaults.removeObject(forKey: "widgetItems"); userDefaults.synchronize()
        if let containerURL = getSharedContainerURL() {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs { try fileManager.removeItem(at: fileURL) }
                print("✅ 已清除所有 App Group 中的暫存檔案。")
            } catch { print("❌ 清除 App Group 檔案時出錯: \(error)") }
        }
        print("✅✅✅ 已執行硬重置。"); dataLoadError = nil; objectWillChange.send()
    }
    
    func moveItemToTrash(item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isTrashed = true; items[index].timestamp = Date()
        sortAndSave()
    }

    func recoverItemFromTrash(item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isTrashed = false; items[index].timestamp = Date()
        sortAndSave()
    }

    func permanentlyDeleteItem(item: ClipboardItem) {
        if let filename = item.filename, let containerURL = getSharedContainerURL() {
            let fileURL = containerURL.appendingPathComponent(filename); try? fileManager.removeItem(at: fileURL)
        }
        items.removeAll { $0.id == item.id }
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { cloudKitManager.delete(itemID: item.id) }
        sortAndSave(skipCloud: true)
    }
    
    func emptyTrash() {
        let trashedItems = items.filter { $0.isTrashed }
        for item in trashedItems { permanentlyDeleteItem(item: item) }
    }
    
    nonisolated func getSharedContainerURL() -> URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) }

    nonisolated func loadFileData(filename: String) -> Data? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        let fileURL = containerURL.appendingPathComponent(filename)
        do { return try Data(contentsOf: fileURL) } catch { return nil }
    }

    func sortAndSave(skipCloud: Bool = false) {
        guard dataLoadError == nil else { print("‼️ 偵測到資料載入錯誤，已阻止儲存操作以保護原始資料。"); return }
        items.sort { item1, item2 in
            if item1.isPinned != item2.isPinned { return item1.isPinned && !item2.isPinned }
            return item1.timestamp > item2.timestamp
        }
        guard didInitializeSuccessfully else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            var itemsToEncode = items
            for i in itemsToEncode.indices { if itemsToEncode[i].fileData != nil && itemsToEncode[i].filename != nil { itemsToEncode[i].fileData = nil } }
            let encodedData = try encoder.encode(itemsToEncode)
            userDefaults.set(encodedData, forKey: "clippedItems"); userDefaults.set(currentDataVersion, forKey: "dataModelVersion"); userDefaults.removeObject(forKey: "clippedItems_corrupted_backup")
            saveWidgetData(); self.updateActivity()
        } catch { print("❌ saveItems: JSON 編碼失败: \(error.localizedDescription)"); dataLoadError = error }
    }
    
    private func saveWidgetData() {
        let activeItems = self.items.filter { !$0.isTrashed }; let topItems = activeItems.prefix(10)
        let widgetItems: [ClipboardItem] = topItems.map { item in
            var newItem = item; newItem.fileData = nil
            if newItem.content.count > 1000 { newItem.content = String(newItem.content.prefix(1000)) }
            return newItem
        }
        if let data = try? JSONEncoder().encode(widgetItems) { userDefaults.set(data, forKey: "widgetItems") }
    }
    
    func updateAndSync(item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item; items[index].timestamp = Date()
        sortAndSave()
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { cloudKitManager.save(item: items[index]) }
    }
    
    func loadItems() {
        guard didInitializeSuccessfully else { return }
        let storedVersion = userDefaults.integer(forKey: "dataModelVersion")
        guard let data = userDefaults.data(forKey: "clippedItems") else { self.items = []; return }
        if storedVersion < currentDataVersion {
            print("ℹ️ 偵測到舊版本資料 (版本 \(storedVersion))，將嘗試進行遷移至版本 \(currentDataVersion)...")
            migrate(from: storedVersion, data: data); return
        }
        do {
            let decodedItems = try JSONDecoder().decode([ClipboardItem].self, from: data)
            self.items = decodedItems; self.dataLoadError = nil
        } catch {
            print("‼️‼️‼️ 嚴重：讀取資料時發生解碼錯誤: \(error.localizedDescription)")
            userDefaults.set(data, forKey: "clippedItems_corrupted_backup"); self.items = []; self.dataLoadError = error
        }
    }
    
    private func migrate(from oldVersion: Int, data: Data) {
        var migratedItems: [ClipboardItem] = []
        do {
            if oldVersion < 2 {
                let oldItems = try JSONDecoder().decode([ClipboardItemV1].self, from: data)
                migratedItems = oldItems.map { ClipboardItem(id: $0.id, content: $0.content, type: $0.type, filename: $0.filename, timestamp: $0.timestamp, isPinned: $0.isPinned, displayName: nil, isTrashed: $0.isTrashed, tags: nil) }
            } else if oldVersion < 3 {
                let oldItems = try JSONDecoder().decode([ClipboardItemV2].self, from: data)
                migratedItems = oldItems.map { ClipboardItem(id: $0.id, content: $0.content, type: $0.type, filename: $0.filename, timestamp: $0.timestamp, isPinned: $0.isPinned, displayName: $0.displayName, isTrashed: $0.isTrashed, tags: nil) }
            }
            self.items = migratedItems; print("✅ 資料遷移成功！共遷移 \(self.items.count) 個項目。")
            self.dataLoadError = nil; sortAndSave()
        } catch {
            print("❌❌❌ 資料遷移失敗: \(error.localizedDescription)"); userDefaults.set(data, forKey: "clippedItems_corrupted_backup"); self.items = []; self.dataLoadError = error
        }
    }

    private func createExportableItems(from items: [ClipboardItem]) -> [ExportableClipboardItem] {
        return items.map { item in
            var exportableItem = ExportableClipboardItem(id: item.id, content: item.content, type: item.type, filename: item.filename, timestamp: item.timestamp, isPinned: item.isPinned, displayName: item.displayName, isTrashed: item.isTrashed, tags: item.tags, fileData: nil)
            if let filename = item.filename { exportableItem.fileData = loadFileData(filename: filename) }
            return exportableItem
        }
    }
    
    private func getTimestampedBackupURL(prefix: String) -> URL {
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"; let dateString = formatter.string(from: Date())
        let filename = "\(prefix)-\(dateString).json"; let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: tempURL.path) { try? FileManager.default.removeItem(at: tempURL) }
        return tempURL
    }

    func exportData() throws -> URL {
        let itemsToExport = createExportableItems(from: self.items)
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; let data = try encoder.encode(itemsToExport)
        let tempURL = getTimestampedBackupURL(prefix: "ClippyIsle-Backup"); try data.write(to: tempURL); return tempURL
    }

    func exportData(forTags tags: Set<String>) throws -> URL? {
        guard !tags.isEmpty else { return nil }
        let filteredItems = self.items.filter { item in guard let itemTags = item.tags else { return false }; return !tags.isDisjoint(with: itemTags) }
        guard !filteredItems.isEmpty else { return nil }
        let itemsToExport = createExportableItems(from: filteredItems)
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; let data = try encoder.encode(itemsToExport)
        let tempURL = getTimestampedBackupURL(prefix: "ClippyIsle-Tagged-Backup"); try data.write(to: tempURL); return tempURL
    }

    func importData(from url: URL) throws -> Int {
        guard url.startAccessingSecurityScopedResource() else { throw NSError(domain: "ClipboardManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "無法存取檔案。"]) }
        defer { url.stopAccessingSecurityScopedResource() }
        let data = try Data(contentsOf: url); var newItemsCount = 0
        let importedItems = try JSONDecoder().decode([ExportableClipboardItem].self, from: data)
        let existingIDs = Set(self.items.map { $0.id })
        
        for importedItem in importedItems {
            guard !existingIDs.contains(importedItem.id) else { continue }
            var newItem = ClipboardItem(id: importedItem.id, content: importedItem.content, type: importedItem.type, filename: importedItem.filename, timestamp: importedItem.timestamp, isPinned: importedItem.isPinned, displayName: importedItem.displayName, isTrashed: importedItem.isTrashed, tags: importedItem.tags, fileData: nil)
            if let fileData = importedItem.fileData {
                if let newFilename = saveFileDataToAppGroup(data: fileData, type: importedItem.type) { newItem.filename = newFilename }
            }
            self.items.append(newItem); newItemsCount += 1
        }
        if newItemsCount > 0 { sortAndSave(); if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { Task { await performCloudSync() } } }
        return newItemsCount
    }

    func cleanupItems() {
        let clearAfterDays = UserDefaults.standard.integer(forKey: "clearAfterDays")
        let maxItemCount = UserDefaults.standard.integer(forKey: "maxItemCount")
        let isDayCleanupEnabled = (clearAfterDays > 0); let isCountCleanupEnabled = (maxItemCount > 0)
        var itemsDidChange = false; var tempItems = items

        if isDayCleanupEnabled {
            let dateLimit = Calendar.current.date(byAdding: .day, value: -clearAfterDays, to: Date())!
            let originalCount = tempItems.count
            tempItems.removeAll { !$0.isPinned && !$0.isTrashed && $0.timestamp < dateLimit }
            if tempItems.count != originalCount { itemsDidChange = true }
        }

        if isCountCleanupEnabled && tempItems.filter({ !$0.isTrashed }).count > maxItemCount {
            tempItems.sort { $0.timestamp > $1.timestamp }; tempItems.sort { $0.isPinned && !$1.isPinned }
            while tempItems.filter({ !$0.isTrashed }).count > maxItemCount {
                if let lastNonPinnedIndex = tempItems.lastIndex(where: { !$0.isPinned && !$0.isTrashed }) {
                    let itemToDelete = tempItems[lastNonPinnedIndex]; tempItems.remove(at: lastNonPinnedIndex)
                    if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { cloudKitManager.delete(itemID: itemToDelete.id) }
                } else { break }
            }
            itemsDidChange = true
        }
        if itemsDidChange { items = tempItems; sortAndSave(skipCloud: true) }
    }

    func togglePin(for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle(); updateAndSync(item: items[index])
    }

    func renameItem(item: ClipboardItem, newName: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].displayName = newName.isEmpty ? nil : newName; updateAndSync(item: items[index])
    }
    
    func createDisplayName(from content: String, isURL: Bool = false, maxLength: Int = 30) -> String? {
        if isURL, content.count > maxLength, let url = URL(string: content), let host = url.host {
            return host.count > maxLength ? String(host.prefix(maxLength)) + "..." : host
        }
        if content.count > maxLength { return String(content.replacingOccurrences(of: "\n", with: " ").prefix(maxLength)) + "..." }
        return nil
    }

    @MainActor
    func checkClipboard(isManual: Bool = false) {
        let askToPaste = UserDefaults.standard.bool(forKey: "askToAddFromClipboard")
        if !isManual && !askToPaste { return }
        let pasteboard = UIPasteboard.general
        guard let providers = pasteboard.itemProviders.first else { return }

        Task {
            if pasteboard.hasImages {
                if let image = pasteboard.image, let imageData = image.pngData(),
                   !items.contains(where: { !$0.isTrashed && $0.type == UTType.png.identifier && $0.filename.flatMap(loadFileData) == imageData }) {
                    addNewItem(content: "圖片", type: UTType.png.identifier, fileData: imageData)
                    return
                }
            }
            
            // **NEW**: Support for .txt files from Files app (public.file-url)
            if providers.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                do {
                    // 修正：明確宣告 Closure 的型別，解決編譯器無法推斷 T 的問題
                    let item = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
                        providers.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                            if let error { continuation.resume(throwing: error) }
                            else { continuation.resume(returning: item) }
                        }
                    }
                    
                    if let url = item as? URL, url.pathExtension.lowercased() == "txt" {
                        // 注意：URL 可能需要 startAccessingSecurityScopedResource，但如果是剪貼簿的公開 URL 通常不需要
                        let data = try Data(contentsOf: url)
                        if let content = String(data: data, encoding: .utf8), !content.isEmpty,
                           !items.contains(where: { !$0.isTrashed && $0.content == content }) {
                            addNewItem(content: content, type: UTType.text.identifier)
                            return
                        }
                    }
                } catch {
                    print("⚠️ ClipboardManager: Failed to load .txt file: \(error.localizedDescription)")
                }
            }
            
            if pasteboard.hasStrings, let content = pasteboard.string, !content.isEmpty,
               !items.contains(where: { !$0.isTrashed && $0.content == content }) {
                // Check if content is a valid URL with http/https scheme
                let isURL: Bool = {
                    guard let url = URL(string: content) else { return false }
                    return url.scheme == "http" || url.scheme == "https"
                }()
                addNewItem(content: content, type: isURL ? UTType.url.identifier : UTType.text.identifier)
                return
            }
        }
    }

    func extractTextFrom(data: Data, type: UTType) -> String? {
        if type == .pdf, let pdf = PDFDocument(data: data) { return (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n") }
        else if type == .rtf, let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) { return attrString.string }
        else if type == .plainText { return String(data: data, encoding: .utf8) }
        return nil
    }

    func addNewItem(content: String, type: String, fileData: Data? = nil) {
        var newItem = ClipboardItem(content: content, type: type, fileData: fileData)
        if let data = fileData {
            if let filename = saveFileDataToAppGroup(data: data, type: type) { newItem.filename = filename; newItem.fileData = nil }
        }
        if let data = fileData, let utType = UTType(type), (utType.conforms(to: .pdf) || utType.conforms(to: .rtf)) {
            if let extractedText = extractTextFrom(data: data, type: utType), !extractedText.isEmpty { newItem.content = extractedText }
        }
        items.insert(newItem, at: 0); sortAndSave()
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { cloudKitManager.save(item: newItem) }
    }
    
    nonisolated func saveFileDataToAppGroup(data: Data, type: String) -> String? {
        guard let containerURL = getSharedContainerURL() else { print("❌ 無法儲存檔案：App Group 容器無法使用。"); return nil }
        let filename = "\(UUID().uuidString).\(UTType(type)?.preferredFilenameExtension ?? "data")"
        let fileURL = containerURL.appendingPathComponent(filename)
        do { try data.write(to: fileURL); return filename } catch { print("❌ 儲存檔案 \(filename) 失敗: \(error.localizedDescription)"); return nil }
    }
    
    nonisolated func saveAssetToAppGroup(from url: URL, originalFilename: String?) -> String? {
        guard let containerURL = getSharedContainerURL() else { return nil }
        let ext = originalFilename.flatMap { URL(fileURLWithPath: $0).pathExtension } ?? "data"
        let newFilename = "\(UUID().uuidString).\(ext)"; let dstURL = containerURL.appendingPathComponent(newFilename)
        do {
            if FileManager.default.fileExists(atPath: dstURL.path) { try FileManager.default.removeItem(at: dstURL) }
            try FileManager.default.copyItem(at: url, to: dstURL); return newFilename
        } catch { print("❌ Copy Asset Failed: \(error)"); return nil }
    }

    func syncActivityState() { Task { await ensureLiveActivityIsRunningIfNeeded() } }
    
    @MainActor
    func ensureLiveActivityIsRunningIfNeeded() async {
        guard await ActivityAuthorizationInfo().areActivitiesEnabled else {
            if isLiveActivityOn { isLiveActivityOn = false; UserDefaults.standard.set(false, forKey: "isLiveActivityOn") }
            return
        }
        let activities = Activity<ClippyIsleAttributes>.activities
        if isLiveActivityOn {
            if activities.isEmpty { await self.startActivity() }
            else { self.activity = activities.first; self.updateActivity() }
        } else { if !activities.isEmpty { await self.endActivity() } }
    }

    func startActivity() async {
        guard didInitializeSuccessfully, Activity<ClippyIsleAttributes>.activities.isEmpty else {
            if activity == nil { activity = Activity<ClippyIsleAttributes>.activities.first }
            if !isLiveActivityOn { isLiveActivityOn = true; UserDefaults.standard.set(true, forKey: "isLiveActivityOn") }
            return
        }
        let themeColorName = UserDefaults.standard.string(forKey: "themeColorName") ?? "blue"
        let activeItemCount = items.filter { !$0.isTrashed }.count
        let attributes = ClippyIsleAttributes()
        let contentState = ClippyIsleAttributes.ContentState(itemCount: activeItemCount, themeColorName: themeColorName, itemsLabel: String(localized: "items"))
        let content = ActivityContent(state: contentState, staleDate: nil)
        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            self.activity = activity; isLiveActivityOn = true; UserDefaults.standard.set(true, forKey: "isLiveActivityOn")
        } catch {
            print("❌ Live Activity 啟動失敗: \(error)"); isLiveActivityOn = false; UserDefaults.standard.set(false, forKey: "isLiveActivityOn")
        }
    }

    func updateActivity(newColorName: String? = nil) {
        guard let activity, activity.activityState == .active else { return }
        let themeColorName = newColorName ?? (UserDefaults.standard.string(forKey: "themeColorName") ?? "blue")
        let activeItemCount = items.filter { !$0.isTrashed }.count
        let contentState = ClippyIsleAttributes.ContentState(itemCount: activeItemCount, themeColorName: themeColorName, itemsLabel: String(localized: "items"))
        let content = ActivityContent(state: contentState, staleDate: nil)
        Task { await activity.update(content) }
    }

    func endActivity() async {
        let activitiesToEnd = Activity<ClippyIsleAttributes>.activities
        guard !activitiesToEnd.isEmpty else {
            activity = nil
            if isLiveActivityOn { isLiveActivityOn = false; UserDefaults.standard.set(false, forKey: "isLiveActivityOn") }
            return
        }
        for activity in activitiesToEnd { await activity.end(nil, dismissalPolicy: .immediate) }
        activity = nil; isLiveActivityOn = false; UserDefaults.standard.set(false, forKey: "isLiveActivityOn")
    }

    var allTags: [String] {
        let allTagsSet = items.reduce(into: Set<String>()) { set, item in guard let tags = item.tags else { return }; set.formUnion(tags) }
        let allTagsArray = Array(allTagsSet)
        
        // Load custom tag order from UserDefaults
        if let customOrder = UserDefaults.standard.array(forKey: "customTagOrder") as? [String] {
            // Create ordered list based on custom order, then append any new tags not in the custom order
            var orderedTags: [String] = []
            for tag in customOrder {
                if allTagsArray.contains(tag) {
                    orderedTags.append(tag)
                }
            }
            // Add any tags that weren't in the custom order (sorted alphabetically)
            let remainingTags = allTagsArray.filter { !orderedTags.contains($0) }.sorted()
            orderedTags.append(contentsOf: remainingTags)
            return orderedTags
        }
        
        return allTagsArray.sorted()
    }
    
    func saveTagOrder(_ tags: [String]) {
        UserDefaults.standard.set(tags, forKey: "customTagOrder")
    }
    
    func updateTags(for item: inout ClipboardItem, newTags: [String]?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let sortedTags = newTags?.sorted(); item.tags = (sortedTags?.isEmpty ?? true) ? nil : sortedTags; items[index].tags = item.tags
        updateAndSync(item: items[index])
    }
    
    func renameTag(from oldName: String, to newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, oldName != newName else { return }
        for i in items.indices {
            if var tags = items[i].tags, tags.contains(oldName) {
                tags.removeAll { $0 == oldName }; if !tags.contains(newName) { tags.append(newName) }
                items[i].tags = tags.sorted()
                if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { cloudKitManager.save(item: items[i]) }
            }
        }
        
        // Update custom tag order
        if var customOrder = UserDefaults.standard.array(forKey: "customTagOrder") as? [String],
           let index = customOrder.firstIndex(of: oldName) {
            customOrder[index] = newName
            UserDefaults.standard.set(customOrder, forKey: "customTagOrder")
        }
        
        sortAndSave()
    }

    func deleteTagFromAllItems(_ tag: String) {
        for i in items.indices {
            items[i].tags?.removeAll { $0 == tag }; if items[i].tags?.isEmpty == true { items[i].tags = nil }
            if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") { cloudKitManager.save(item: items[i]) }
        }
        
        // Remove from custom tag order
        if var customOrder = UserDefaults.standard.array(forKey: "customTagOrder") as? [String] {
            customOrder.removeAll { $0 == tag }
            UserDefaults.standard.set(customOrder, forKey: "customTagOrder")
        }
        
        sortAndSave()
    }
}