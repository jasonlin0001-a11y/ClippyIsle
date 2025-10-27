import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import Combine // 導入 Combine
import WebKit // 導入 WebKit
import AudioToolbox // 【新功能】 為了複製震動回饋

// MARK: - App Group 常數
let appGroupID = "group.com.shihchieh.clippyisle"

// MARK: - 【V3 修復】 將 saveFileData 移出 MainActor
// 將資料寫入共享容器 (用於自動抓取 / 拖曳)
// 這現在是一個獨立函式，可以在任何執行緒上被呼叫
func saveFileDataToAppGroup(data: Data, type: String) -> String? {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
        print("❌ [偵錯] 儲存檔案失敗：無法取得共享容器 URL。")
        return nil
    }

    let id = UUID().uuidString
    let utType = UTType(type)
    let fileExtension = utType?.preferredFilenameExtension ?? "data"
    let filename = "\(id).\(fileExtension)"
    let fileURL = containerURL.appendingPathComponent(filename)

    do {
        try data.write(to: fileURL)
        print("✅ [偵錯] 成功將檔案寫入: \(filename)")
        return filename
    } catch {
        print("❌ [偵錯] 寫入檔案 \(filename) 失敗: \(error.localizedDescription)")
        return nil
    }
}


// MARK: - 【V3 修復】 補回 AppearanceMode
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }

    // 【本地化】 改用 Key
    var name: LocalizedStringKey {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light Mode"
        case .dark:
            return "Dark Mode"
        }
    }
}

// MARK: - 【V3 修復】 補回 ClipboardItem
// 【V3 修復】 新增 displayName 用於 URL 更名
struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    var content: String
    var type: String
    var filename: String? // 用於儲存大檔案的名稱
    var isPinned: Bool = false
    var timestamp: Date // 【新功能】 紀錄複製時間
    var displayName: String? // 【V3 修復】 用於 URL 更名

    var fileData: Data? = nil

    enum CodingKeys: String, CodingKey {
        case id, content, type, filename, isPinned, timestamp
        case displayName // 【V3 修復】 新增
    }
}

// MARK: - 【V3 修復】 補回 ClippyIsleAttributes
// !!! 這必須與 ClippyIsleWidget.swift 中的定義完全一致 !!!
struct ClippyIsleAttributes: ActivityAttributes {
    
    // 【V3 修復】 將 ColorUtility 嵌套於此，確保 App 和 Widget 100% 同步
    struct ColorUtility {
        static func color(forName name: String) -> Color {
            switch name.lowercased() {
            case "green": return .green
            case "orange": return .orange
            case "red": return .red
            case "pink": return .pink
            case "purple": return .purple
            case "black": return .black
            case "white": return .white
            default: return .blue
            }
        }
    }
    
    public struct ContentState: Codable, Hashable {
        var itemCount: Int
        var themeColorName: String
        var itemsLabel: String // 【V3 修復】 新增本地化標籤
    }
    // 【本地化】 appName 改為在啟動時傳入
}

// MARK: - 【V3 修復】 補回 ClipboardManager
@MainActor
class ClipboardManager: ObservableObject {

    @Published var items: [ClipboardItem] = [] {
        // 【功能修改】 移除 didSet，改由 sortAndSave 手動觸發
         didSet {
             // 【功能修改】 釘選/刪除/新增時，自動觸發排序、儲存和更新
             if !isSorting { // 防止在排序時重複觸發
                 sortAndSave()
             }
         }
    }

    @Published var activity: Activity<ClippyIsleAttributes>? = nil
    // 【功能修改】 移除 didSet，改用 .onChange 處理非同步
    @Published var isLiveActivityOn: Bool

    // 【功能修改】 用於防止排序時觸發 didSet
    var isSorting = false

    let userDefaults: UserDefaults
    let fileManager = FileManager.default // FileManager 現在是類別屬性

    // 【穩定性修復】 移除 lastImported... 檢查，放寬重複貼上的限制
    // private var lastImportedContent: String?
    // private var lastImportedImageData: Data?

    // 【錯誤修正】 將 init() 宣告為 public
    public init() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            fatalError("❌ [偵錯] 致命錯誤: 無法初始化 App Group UserDefaults。請檢查 App Group ID 是否正確並在 'Signing & Capabilities' 中設定。")
        }
        self.userDefaults = defaults
        print("✅ [偵錯] UserDefaults 初始化成功。")

        // 從標準 UserDefaults 讀取開關狀態
        self.isLiveActivityOn = UserDefaults.standard.bool(forKey: "isLiveActivityOn")

        loadItems()
        cleanupItems() // 【新功能】 啟動時執行清理
        // 【穩定性修復】 syncActivityState 留到 onAppear 且權限確認後再做
    }

    // 取得 App Group 共享資料夾的 URL
    func getSharedContainerURL() -> URL? {
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    // 【錯誤修正】 saveFileData 已被移出此類別 (避免 MainActor 警告)

    // 從共享資料夾載入檔案資料
    func loadFileData(filename: String) -> Data? {
        guard let containerURL = getSharedContainerURL() else {
            print("❌ [偵錯] 載入檔案失敗：無法取得共享容器 URL。")
            return nil
        }
        let fileURL = containerURL.appendingPathComponent(filename)
        do {
            // 【V3 修復】 修正 "No exact matches" 錯誤，明確加入 options
            let data = try Data(contentsOf: fileURL, options: [])
            print("✅ [偵錯] 成功從 \(filename) 載入檔案資料。")
            return data
        } catch {
            print("❌ [偵錯] 載入檔案 \(filename) 失败: \(error.localizedDescription)")
            return nil
        }
    }

    // 【功能修改】 排序、儲存、更新 (三合一)
    func sortAndSave() {
        print("ℹ️ [偵錯] 執行 sortAndSave...")
        isSorting = true // 標記開始排序

        // 1. 排序 (釘選優先，然後時間)
        items.sort { $0.timestamp > $1.timestamp }
        items.sort { $0.isPinned && !$1.isPinned }

        // 2. 儲存 (Metadata)
        guard let defaults = userDefaults as UserDefaults? else {
            isSorting = false
            return
        }

        do {
            let encodedData = try JSONEncoder().encode(items)
            defaults.set(encodedData, forKey: "clippedItems")
            print("✅ [偵錯] saveItems: 成功儲存 \(items.count) 個項目。")
        } catch {
            print("❌ [偵錯] saveItems: JSON 編碼失敗: \(error.localizedDescription)")
        }

        // 3. 更新動態島
        updateActivity()

        isSorting = false // 標記結束排序
    }


    // 載入項目列表 (Metadata)
    func loadItems() {
        guard let data = userDefaults.data(forKey: "clippedItems") else {
            print("ℹ️ [偵錯] loadItems: 找不到 'clippedItems' 鍵，可能是首次啟動。")
            return
        }

        do {
            let decodedItems = try JSONDecoder().decode([ClipboardItem].self, from: data)
            // 【功能修改】 載入時才排序
            var sortedItems = decodedItems
            sortedItems.sort { $0.timestamp > $1.timestamp }
            sortedItems.sort { $0.isPinned && !$1.isPinned }

            self.items = sortedItems
            print("✅ [偵錯] loadItems: 成功載入 \(decodedItems.count) 個項目。")
        } catch {
            print("❌ [偵錯] loadItems: JSON 解碼失敗: \(error)。這可能是因為資料結構已變更。")
            // 【修復】 如果解碼失敗 (資料結構不相容)，自動清除舊的損壞資料
            userDefaults.removeObject(forKey: "clippedItems")
            self.items = []
            print("ℹ️ [偵錯] loadItems: 已清除損壞的舊資料。")
        }
    }

    // 【新功能】 清理舊的或多餘的項目
    func cleanupItems() {
        print("ℹ️ [偵錯] 執行清理...")

        // 從標準 UserDefaults 讀取設定
        let clearAfterDays = UserDefaults.standard.integer(forKey: "clearAfterDays")
        let maxItemCount = UserDefaults.standard.integer(forKey: "maxItemCount")

        // 預設值 (如果使用者從未開啟過設定)
        let effectiveDays = (clearAfterDays == 0 && maxItemCount == 0) ? 30 : clearAfterDays
        let effectiveCount = (clearAfterDays == 0 && maxItemCount == 0) ? 100 : maxItemCount

        var itemsDidChange = false
        var tempItems = self.items

        // 1. 根據天數清理 (0 = 永不)
        if effectiveDays > 0 {
            let calendar = Calendar.current
            let dateLimit = calendar.date(byAdding: .day, value: -effectiveDays, to: Date())!

            let originalCount = tempItems.count
            // 只移除未釘選且早於限制日期的項目
            tempItems.removeAll { !$0.isPinned && $0.timestamp < dateLimit }

            if tempItems.count != originalCount {
                print("ℹ️ [偵錯] 清理：移除了 \(originalCount - tempItems.count) 個超過 \(effectiveDays) 天的項目。")
                itemsDidChange = true
            }
        }

        // 2. 根據最大數量清理 (0 = 無限制)
        if effectiveCount > 0 && tempItems.count > effectiveCount {
            print("ℹ️ [偵錯] 清理：項目 \(tempItems.count) 個，超過最大數量 \(effectiveCount)。")
            // 再次確保排序正確 (釘選的在最前面)
            tempItems.sort { $0.timestamp > $1.timestamp }
            tempItems.sort { $0.isPinned && !$1.isPinned }

            // 移除多餘的 (會自動從後面開始刪，保留最新的)
            while tempItems.count > effectiveCount {
                // 尋找最後一個未釘選的項目並移除
                if let lastNonPinnedIndex = tempItems.lastIndex(where: { !$0.isPinned }) {
                    tempItems.remove(at: lastNonPinnedIndex)
                } else {
                    // 如果全都是釘選的，且還是超過數量，那就沒辦法了，停止移除
                    break
                }
            }
            itemsDidChange = true
        }

        if itemsDidChange {
            self.items = tempItems
            // sortAndSave() 會被 @Published 自動觸發
        }
    }

    // 【新功能】 釘選/取消釘選
    func togglePin(for item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        // sortAndSave() 會被 @Published 自動觸發 (並重新排序)
    }

    // 【新功能】 更名
    // 【V3 修復】 區分 URL 和一般文字
    func renameItem(item: ClipboardItem, newName: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        // 【V5 文字更名修復】
        // 統一邏輯：更名 *永遠* 只是修改 displayName，*絕對* 不動 content
        // 如果新名稱為空，則清除 displayName (恢復顯示 content)
        items[index].displayName = newName.isEmpty ? nil : newName
        
        // sortAndSave() 會被 @Published 自動觸發
    }
    
    // 【V5 標題修復】 新增輔助函式，自動截斷長內容
    private func createDisplayName(from content: String, isURL: Bool = false, maxLength: Int = 30) -> String? { //【修復】 將 80 改為 30
        // 如果是 URL 且長度 > maxLength，試著只取 host
        if isURL, content.count > maxLength, let url = URL(string: content), let host = url.host {
            // 如果 host 還是太長, 就截斷 host
            if host.count > maxLength {
                return String(host.prefix(maxLength)) + "..."
            }
            // 否則使用 host (例如 www.google.com)
            return host
        }
        
        // 如果是文字或短 URL
        if content.count > maxLength {
            // 移除換行符號，然後截斷
            let trimmedContent = content.replacingOccurrences(of: "\n", with: " ")
            return String(trimmedContent.prefix(maxLength)) + "..."
        }
        
        // 如果內容不長，不需要 displayName，直接顯示 content 即可
        return nil
    }


    // MARK: - 【新功能】 自動抓取剪貼簿
    @MainActor
    func checkClipboard() {
        print("ℹ️ [偵錯] 正在檢查系統剪貼簿...")
        let pasteboard = UIPasteboard.general

        // 1. 檢查圖片
        if let image = pasteboard.image {
            // 【修復】 明確使用 PNG 資料
            guard let imageData = image.pngData() else { return }

            // 檢查圖片是否已存在於列表 (以檔案大小為依據)
            let existingImageFilenames = items.filter { $0.type == UTType.png.identifier }.compactMap { $0.filename }
            for filename in existingImageFilenames {
                if let data = loadFileData(filename: filename), data == imageData {
                    print("ℹ️ [偵錯] 剪貼簿中的圖片已存在於列表中。")
                    return
                }
            }

            print("ℹ️ [偵錯] 偵測到新圖片，正在儲存...")
            let filename = saveFileDataToAppGroup(data: imageData, type: UTType.png.identifier)

            let newItem = ClipboardItem(
                id: UUID(),
                content: String(localized: "Image"), // 【本地化】
                type: UTType.png.identifier, // 【修復】
                filename: filename,
                isPinned: false,
                timestamp: Date(),
                displayName: nil // 圖片不需要預設 displayName
            )

            items.insert(newItem, at: 0)
            print("✅ [偵錯] 成功從剪貼簿加入圖片。")

        // 2. 檢查 URL
        } else if let url = pasteboard.url {
            let urlString = url.absoluteString

            if items.contains(where: { $0.content == urlString && $0.type == UTType.url.identifier }) {
                print("ℹ️ [偵錯] 剪貼簿中的 URL 已存在於列表中。")
                return
            }

            print("ℹ️ [偵錯] 偵測到新 URL: \(urlString)")
            let newItem = ClipboardItem(
                id: UUID(),
                content: urlString,
                type: UTType.url.identifier,
                filename: nil,
                isPinned: false,
                timestamp: Date(),
                // 【V5 標題修復】 自動建立 displayName
                displayName: createDisplayName(from: urlString, isURL: true)
            )

            items.insert(newItem, at: 0)

        // 3. 檢查純文字
        } else if let text = pasteboard.string, !text.isEmpty {

             if items.contains(where: { $0.content == text && $0.type == UTType.text.identifier }) {
                print("ℹ️ [偵錯] 剪貼簿中的文字已存在於列表中。")
                return
            }

            print("ℹ️ [偵錯] 偵測到新文字: \(text.prefix(30))...")

            // 檢查文字是否其實是 URL
            let itemType = (URL(string: text) != nil && (text.starts(with: "http") || text.starts(with: "https"))) ? UTType.url.identifier : UTType.text.identifier

            let newItem = ClipboardItem(
                id: UUID(),
                content: text,
                type: itemType,
                filename: nil,
                isPinned: false,
                timestamp: Date(),
                // 【V5 標題修復】 自動建立 displayName
                displayName: createDisplayName(from: text, isURL: itemType == UTType.url.identifier)
            )

            items.insert(newItem, at: 0)
        } else {
             print("ℹ️ [偵錯] 剪貼簿為空或包含不支援的類型。")
        }
    }

    // MARK: - 【新功能】 處理從其他 App 拖曳進來的項目
    // 【錯誤修正】 移除 @MainActor，因為它會在背景執行緒被呼叫
    func handleDroppedProviders(_ providers: [NSItemProvider]) {
        print("ℹ️ [偵錯] 偵測到拖曳項目: \(providers.count) 個")

        for provider in providers {
            // 優先處理檔案 URL (例如從「檔案」App 拖曳)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                    guard let url = item as? URL, error == nil else {
                        print("❌ [偵錯] 拖曳 fileURL 失敗: \(error?.localizedDescription ?? "未知錯誤")")
                        return
                    }

                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }

                        do {
                            let data = try Data(contentsOf: url)
                            let filename = url.lastPathComponent
                            let type = UTType(filenameExtension: url.pathExtension)?.identifier ?? UTType.data.identifier

                            print("✅ [偵錯] 拖曳 fileURL 成功: \(filename) (\(data.count) bytes)")

                            let savedFilename = saveFileDataToAppGroup(data: data, type: type)

                            DispatchQueue.main.async {
                                let newItem = ClipboardItem(
                                    id: UUID(),
                                    content: filename, // 顯示檔名
                                    type: type,
                                    filename: savedFilename,
                                    isPinned: false,
                                    timestamp: Date(),
                                    displayName: nil // 檔案名稱不需要 displayName
                                )
                                self.items.insert(newItem, at: 0)
                            }
                        } catch {
                            print("❌ [偵錯] 拖曳 fileURL 讀取資料失敗: \(error.localizedDescription)")
                        }
                    } else {
                        print("❌ [偵錯] 拖曳 fileURL 無法存取安全範圍資源。")
                    }
                }
            }
            // 處理圖片 (例如從「照片」App 或 Safari 拖曳)
            else if provider.canLoadObject(ofClass: UIImage.self) {
                _ = provider.loadObject(ofClass: UIImage.self) { (object, error) in
                    guard let image = object as? UIImage, let data = image.pngData() else { return }

                    print("✅ [偵錯] 拖曳 UIImage 成功 (\(data.count) bytes)")
                    let filename = saveFileDataToAppGroup(data: data, type: UTType.png.identifier)

                    DispatchQueue.main.async {
                        let newItem = ClipboardItem(
                            id: UUID(),
                            content: String(localized: "Image"), // 【本地化】
                            type: UTType.png.identifier,
                            filename: filename,
                            isPinned: false,
                            timestamp: Date(),
                            displayName: nil // 圖片不需要 displayName
                        )
                        self.items.insert(newItem, at: 0)
                    }
                }
            }
            // 處理 URL (例如從 Safari 網址列拖曳)
            else if provider.canLoadObject(ofClass: URL.self) {
                _ = provider.loadObject(ofClass: URL.self) { (object, error) in
                    guard let url = object else { return }
                    let urlString = url.absoluteString
                    
                    print("✅ [偵錯] 拖曳 URL 成功: \(urlString)")
                    DispatchQueue.main.async {
                        let newItem = ClipboardItem(
                            id: UUID(),
                            content: urlString,
                            type: UTType.url.identifier,
                            filename: nil,
                            isPinned: false,
                            timestamp: Date(),
                            // 【V5 標題修復】 自動建立 displayName
                            displayName: self.createDisplayName(from: urlString, isURL: true)
                        )
                        self.items.insert(newItem, at: 0)
                    }
                }
            }
            // 處理純文字
            else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { (object, error) in
                    guard let text = object else { return }

                    print("✅ [偵錯] 拖曳 String 成功: \(text.prefix(30))...")
                    DispatchQueue.main.async {
                        let itemType = (URL(string: text) != nil && (text.starts(with: "http") || text.starts(with: "https"))) ? UTType.url.identifier : UTType.text.identifier

                        let newItem = ClipboardItem(
                            id: UUID(),
                            content: text,
                            type: itemType,
                            filename: nil,
                            isPinned: false,
                            timestamp: Date(),
                            // 【V5 標題修復】 自動建立 displayName
                            displayName: self.createDisplayName(from: text, isURL: itemType == UTType.url.identifier)
                        )
                        self.items.insert(newItem, at: 0)
                    }
                }
            }
        }
    }

    // MARK: - 動態島控制

    // 【新功能】 同步 App 偏好與系統動態島的實際狀態
    func syncActivityState() {
        let activities = Activity<ClippyIsleAttributes>.activities

        // 檢查系統的實際狀態
        if activities.isEmpty {
            // 系統中 *沒有* 正在執行的動態島
            if self.isLiveActivityOn {
                // 但我們的開關顯示 "On"
                print("ℹ️ [偵錯] sync: 偵測到不同步 (系統中無島，但開關為ON)。將開關設為OFF。")
                self.isLiveActivityOn = false // 【邏輯修復】 以系統狀態為準
                UserDefaults.standard.set(false, forKey: "isLiveActivityOn")
            }
        } else {
            // 系統中 *有* 正在執行的動態島
            self.activity = activities.first // 抓取實例
            if !self.isLiveActivityOn {
                // 但我們的開關顯示 "Off"
                print("ℹ️ [偵錯] sync: 偵測到不同步 (系統中有島，但開關為OFF)。將開關設為ON。")
                self.isLiveActivityOn = true // 【邏輯修復】 以系統狀態為準
                UserDefaults.standard.set(true, forKey: "isLiveActivityOn")
            } else {
                // 狀態一致，更新 activity 實例
                print("ℹ️ [偵錯] sync: 狀態一致，已同步 activity 實例。")
                updateActivity() // 順便更新一下內容
            }
        }
    }

    // 【功能修改】 改為 async
    func startActivity() async {
        // 檢查權限 (在 ContentView 中完成)

        // 檢查是否已有
        guard Activity<ClippyIsleAttributes>.activities.isEmpty else {
            print("ℹ️ [偵錯] Live Activity 已在執行中。")
            self.activity = Activity<ClippyIsleAttributes>.activities.first
            self.isLiveActivityOn = true
            return
        }

        let themeColorName = UserDefaults.standard.string(forKey: "themeColorName") ?? "blue"
        // 【V3 修復】 新增本地化標籤
        let itemsLabel = String(localized: "items")

        let attributes = ClippyIsleAttributes() // appName 已移至 Widget
        let contentState = ClippyIsleAttributes.ContentState(
            itemCount: items.count,
            themeColorName: themeColorName,
            itemsLabel: itemsLabel // 【V3 修復】 傳遞
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            self.activity = activity
            print("✅ [偵錯] Live Activity 啟動成功！")
            // 【功能修改】 確保狀態同步
            DispatchQueue.main.async {
                self.isLiveActivityOn = true
                UserDefaults.standard.set(true, forKey: "isLiveActivityOn")
            }
        } catch {
            print("❌ [偵錯] Live Activity 啟動失敗: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isLiveActivityOn = false // 啟動失敗，把開關關回去
                UserDefaults.standard.set(false, forKey: "isLiveActivityOn")
            }
        }
    }

    // 【V4 修復】 updateActivity 移到這裡，它屬於 ClipboardManager
    // 【V3 白色修復】 允許傳入新顏色，以避免時間差 (race condition)
    func updateActivity(newColorName: String? = nil) {
        // 【功能修改】 只有在 activity 實例存在時才更新
        guard let activity = self.activity, activity.activityState == .active else {
            print("ℹ️ [偵錯] updateActivity: 找不到活動的 activity，不更新。")
            return
        }

        // 【V3 白色修復】 優先使用傳入的 newColorName，如果沒有才讀取 UserDefaults
        let themeColorName = newColorName ?? (UserDefaults.standard.string(forKey: "themeColorName") ?? "blue")
        // 【V3 修復】 新增本地化標籤
        let itemsLabel = String(localized: "items")
        
        let contentState = ClippyIsleAttributes.ContentState(
            itemCount: items.count,
            themeColorName: themeColorName,
            itemsLabel: itemsLabel // 【V3 修復】 傳遞
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        Task {
            await activity.update(content)
            print("ℹ️ [偵錯] Live Activity 已更新，項目總數: \(items.count)，顏色: \(themeColorName)")
        }
    }

    // 【V4 修復】 endActivity 移到這裡，它屬於 ClipboardManager
    // 【功能修改】 改為 async
    func endActivity() async {
        // 【修復】 改為結束所有可能的動態島，並更新狀態
        let tasks = Activity<ClippyIsleAttributes>.activities.map { activity in
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        // 等待所有結束任務完成
        for task in tasks {
            await task.value
        }

        DispatchQueue.main.async {
            self.activity = nil
            self.isLiveActivityOn = false // 確保開關狀態也更新
            UserDefaults.standard.set(false, forKey: "isLiveActivityOn")
            print("ℹ️ [偵錯] Live Activity 已結束。")
        }
    }
}


// MARK: - 【V3 修復】 補回 WebView
struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()

        // 【修復】 允許 YouTube 影片播放
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.allowsPictureInPictureMediaPlayback = true

        // 【VFix】 解決地圖（或其他網站）顯示「不支援的瀏覽S器」問題
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 【修復】 避免不必要的重載
        if let url = URL(string: urlString), uiView.url != url {
             uiView.load(URLRequest(url: url))
        }
    }
}

// MARK: - 【V3 修復】 可選取的文字視圖 (UIViewRepresentable)
// 為了提供完整的原生選單 (翻譯、朗讀) 和網址偵測，
// 我們使用 UIKit 的 UITextView。
struct SelectableTextView: UIViewRepresentable {
    var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        // 【V3 修復】 自動偵測網址
        textView.dataDetectorTypes = .link
        textView.isSelectable = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.text = text
        textView.backgroundColor = .clear // 配合 SwiftUI 背景
        textView.textColor = .label // 配合淺色/深色模式
        return textView
    }



    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}


// MARK: - 項目預覽視圖 (功能更新)
struct PreviewView: View {
    let item: ClipboardItem

    var body: some View {
        // 【修復】 移除內部的 NavigationView
        VStack {
            // 【修復】 確保使用 .png 類型來檢查
            if item.type == UTType.png.identifier, let data = item.fileData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    // 【V3 修復】 .textSelection(.enabled) 是啟用「原況文字」的正確修飾符。
                    // 注意：此功能需要 iOS 16+ 且強烈建議在實體裝置上測試。
                    .textSelection(.enabled)
            } else if item.type == UTType.url.identifier || item.type == UTType.text.identifier && (item.content.starts(with: "http://") || item.content.starts(with: "https")) {
                // 【新功能】 網頁預覽
                // 【V3 修復】 預覽時永遠使用 content (原始 URL)
                WebView(urlString: item.content)
            } else {
                // 【V3 修復】 使用 UITextView (UIViewRepresentable)
                // 這將提供完整的原生選單 (拷貝、查詢、翻譯、朗讀) 並自動啟用網址
                // 【V3 修復】 預覽時永遠使用 content (原始文字)
                SelectableTextView(text: item.content)
                    .padding()
            }
        }
        .navigationTitle(Text("Item Preview")) // 【本地化】
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 【新功能】 設定頁面
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    // 使用 @AppStorage 自動與 UserDefaults 同步
    @AppStorage("maxItemCount") private var maxItemCount: Int = 100
    @AppStorage("clearAfterDays") private var clearAfterDays: Int = 30
    // 【顏色即時更新修復】 移除 @AppStorage，改用 @Binding
    @Binding var themeColorName: String
    // 【即時顏色修復】 移除 let currentThemeColor，改為在內部即時計算
    // let currentThemeColor: Color
    
    // 【新功能】 新增外觀模式儲存
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue = AppearanceMode.system.rawValue

    let countOptions = [50, 100, 200, 0] // 0 = 無限制
    let dayOptions = [7, 30, 90, 0] // 0 = 永不
    // 【新功能】 新增黑色和白色
    let colorOptions = ["blue", "green", "orange", "red", "pink", "purple", "black", "white"]

    // 【即時顏色修復】 在 View 內部即時計算顏色
    var themeColor: Color {
        // 【V3 修復】 改用嵌套的 ColorUtility
        ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }

    // 【新功能】 計算設定頁面本身的外觀
    var preferredColorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceMode) {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil // 'nil' means 'follow the system'
        }
    }

    // 【最終錯誤修正】 使用最標準、最保險的 Form 語法結構
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Max Item Count", selection: $maxItemCount) { // 【本地化】
                        ForEach(countOptions, id: \.self) { count in
                            Text(count == 0 ? LocalizedStringKey("Unlimited") : "\(count) \(String(localized: "items"))").tag(count) // 【本地化】
                        }
                    }

                    Picker("Auto-clean Days", selection: $clearAfterDays) { // 【本地化】
                        ForEach(dayOptions, id: \.self) { days in
                            Text(days == 0 ? LocalizedStringKey("Never") : "\(days) \(String(localized: "days ago"))").tag(days) // 【本地化】
                        }
                    }
                } header: {
                     Text("Storage Policy") // 【本地化】
                } footer: {
                    // 【V6 本地化修復】 將英文說明改為繁體中文
                    Text("App 會在每次啟動時自動清理舊的或多餘的「未釘選」項目。如果天數和數量設為預設值，將套用 30 天 / 100 個項目的規則。") // 【本地化】
                }

                Section {
                    Picker("Display Mode", selection: $appearanceMode) { // 【本地化】
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.name).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented) // 分段樣式

                    // 【顏色即時更新修復】 Picker 現在綁定到 @Binding
                    Picker("Theme Color", selection: $themeColorName) { // 【本地化】
                        ForEach(colorOptions, id: \.self) { colorName in
                            HStack {
                                Image(systemName: "circle.fill")
                                    // 【V3 修復】 改用嵌套的 ColorUtility
                                    .foregroundColor(ClippyIsleAttributes.ColorUtility.color(forName: colorName))
                                    .overlay(
                                        // 【新功能】 加上邊框，讓黑色/白色在不同模式下都可見
                                        Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                                Text(colorName.capitalized).tag(colorName)
                            }
                        }
                    }
                } header: {
                    Text("Appearance") // 【本地化】
                }
            } // Form 結束
            .navigationTitle(Text("Settings")) // 【本地化】
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done") // 【本地M化】
                    }
                }
            }
        } // NavigationView 結束
        // 【即時顏色修復】 在 NavigationView 內部也加上 tint，
        // 確保 Picker 和 "Done" 按鈕即時更新
        .tint(themeColor)
        // 【V3 即時顏色修復】 新增 .id()。
        // 當 themeColorName 改變時，強制 SwiftUI 重建整個 NavigationView，
        // 這是確保 .tint() 被立即應用的最可靠方法。
        .id(themeColorName)
        .preferredColorScheme(preferredColorScheme) // 【新功能】 讓設定頁面本身也套用模式
    }
}


// MARK: - 【V3 修復】 移除獨立的 ColorUtility
/*
struct ColorUtility {
    ...
}
*/

// MARK: - 【新功能】 時間格式化
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        // formatter.locale = Locale(identifier: "zh_Hant_TW") // 【本地化】 移除，讓系統自動選擇
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - 【錯誤修正】 步驟 1: 將 itemIcon 移到 ContentView 外部
// 根據檔案類型顯示不同圖示
func itemIcon(for type: String) -> String {
    let utType = UTType(type)
    if utType?.conforms(to: .image) == true || type == UTType.png.identifier {
        return "photo"
    } else if utType?.conforms(to: .url) == true {
        return "link"
    } else if utType?.conforms(to: .text) == true {
        return "doc.text"
    } else if utType?.conforms(to: .data) == true {
        return "doc"
    } else {
        return "questionmark.diamond"
    }
}

// MARK: - 【錯誤修正】 步驟 2: 建立一個獨立的 View 來放列表的「行」
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let themeColor: Color
    
    // 動作回呼 (Closures)
    var copyAction: () -> Void
    var previewAction: () -> Void
    var createDragItem: () -> NSItemProvider
    var togglePinAction: () -> Void
    var deleteAction: () -> Void
    var renameAction: () -> Void
    var shareAction: () -> Void

    var body: some View {
        HStack(spacing: 15) {

            // 【新功能】 點擊圖示複製
            Button(action: copyAction) {
                Image(systemName: itemIcon(for: item.type))
                    .font(.title3)
                    .frame(width: 30)
                    .foregroundColor(themeColor)
            }
            .buttonStyle(.plain) // 移除按鈕的預設樣式

            VStack(alignment: .leading, spacing: 4) {
                // 【V3 修復】 優先顯示 displayName，如果沒有才顯示 content
                Text(item.displayName ?? item.content)
                    .lineLimit(1)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(item.timestamp.timeAgoDisplay()) // 【新功能】 顯示相對時間
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if item.isPinned { // 釘選圖示
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // 確保整個 HStack 區域都能響應點擊
        .onTapGesture(perform: previewAction) // 【修復】 使用 .onTapGesture 觸發預覽
        .onDrag(createDragItem) // 拖曳功能
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: togglePinAction) {
                Label("Pin", systemImage: item.isPinned ? "pin.slash" : "pin") // 【本地化】
            }
            .tint(item.isPinned ? .gray : .orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // 【修復】 補上滑動刪除功能
            Button(role: .destructive, action: deleteAction) {
                Label("Delete", systemImage: "trash") // 【本地化】
            }
            .tint(.red) // 【V5 紅色修復】 強制刪除按鈕為紅色，不受佈景主題影響

            // 【新功能】 更名按鈕
            Button(action: renameAction) {
                Label("Rename", systemImage: "pencil") // 【本地化】
            }
            .tint(.indigo)

            // 【新功能】 分享按鈕
            Button(action: shareAction) {
                Label("Share", systemImage: "square.and.arrow.up") // 【本地K】
            }
            .tint(.blue)
        }
    }
}


// MARK: - 主畫面
struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var selectedItem: ClipboardItem? // 用於預覽
    @State private var activitiesEnabled: Bool = false // 【穩定性修復】 預設為 false，直到 checkActivityStatus() 確認
    @State private var isShowingSettings = false // 【新功能】

    // 【新功能】 更名用
    @State private var itemToRename: ClipboardItem?
    @State private var newName: String = ""
    @State private var isShowingRenameAlert = false // 【V3 修復】 新增一個 Bool 狀態來觸發 Alert

    // 【新功能】 讀取主題顏色
    @AppStorage("themeColorName") private var themeColorName: String = "blue"
    // 【新功能】 讀取外觀模式
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue = AppearanceMode.system.rawValue

    var themeColor: Color {
        // 【V3 修復】 改用嵌套的 ColorUtility
        ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }

    // 【新功能】 計算 App 應用的外觀
    var preferredColorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceMode) {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return nil // 'nil' means 'follow the system'
        }
    }

    // MARK: - 【V2 錯誤修正】 將 Body 拆分為計算屬性
    
    var body: some View {
        // 這是最外層的 View，只負責處理 .sheet 和 .alert
        Group {
            mainNavigationView // 顯示主畫面
        }
        .sheet(item: $selectedItem) { item in
            // 【修復】 為了讓 "完成" 按鈕生效，我們需要將 PreviewView 包在 NavigationView 中
            NavigationView {
                PreviewView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                selectedItem = nil
                            }) {
                                Text("Done") // 【本地化】
                            }
                        }
                    }
            }
            .tint(themeColor) // 【新功能】 讓 Sheet 也套用主題色
            .preferredColorScheme(preferredColorScheme) // 【新功能】 讓 Sheet 也套用外觀
        }
        // 【新功能】 設定頁面 Sheet
        .sheet(isPresented: $isShowingSettings) {
            // 當設定頁面關閉時，執行清理
            clipboardManager.cleanupItems()
            // 也要更新動態島 (如果顏色變了)
            if clipboardManager.isLiveActivityOn {
                // 【V4 修復】 傳遞當前的顏色 (修復白色主題BUG)
                clipboardManager.updateActivity(newColorName: themeColorName)
            }
        } content: {
            // 【顏色即時更新修復】 將 $themeColorName 綁定傳入 SettingsView
            // 【即時顏色修復】 移除傳遞 currentThemeColor
            SettingsView(themeColorName: $themeColorName)
                // 【即時顏色修復】 將 .tint(themeColor) 加在這裡，
                // 這樣當 ContentView 的 themeColor 改變時，會強制刷新 Sheet 的 tint
                .tint(themeColor)
        }
        // 【新功能】 更名提示框
        // 【V3 修復】 改用 $isShowingRenameAlert 觸發，並移除複雜的 Binding
        .alert(Text("Rename Item"), isPresented: $isShowingRenameAlert) {
            // 【錯誤修正】 TextField 的提示文字不能包在 Text() 裡，直接給字串即可
            TextField("Enter new name", text: $newName) // 【本地化】
            Button(action: {
                if let item = itemToRename {
                    clipboardManager.renameItem(item: item, newName: newName)
                }
                itemToRename = nil
                newName = ""
            }) {
                Text("Save") // 【本地化】
            }
            Button(role: .cancel, action: {
                itemToRename = nil
                newName = ""
            }) {
                Text("Cancel") // 【本地化】
            }
        } message: {
            Text("Enter a new name for the clipboard item.") // 【本地化】
        }
    }
    
    // 【V2 錯誤修正】 這是主畫面 (NavigationView)
    private var mainNavigationView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 動態島權限偵錯
                if !activitiesEnabled {
                    Text("Live Activities permission is not enabled. Please enable it in Settings > ClippyIsle > Live Activities.") // 【本地化】
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                }

                // 顯示列表內容
                listContent
                
            } // VStack 結束
        } // NavigationView 結束
        .tint(themeColor) // 【新功能】 將主題顏色應用到整個 App
        .preferredColorScheme(preferredColorScheme) // 【新功能】 套用外觀模式
        .onAppear {
            checkActivityStatus() // 【穩定性修復】 啟動時檢查權限
        }
        // App 返回前景時
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("ℹ️ [偵錯] App 返回前景，重新載入與同步...")
            checkActivityStatus() // 【穩定性修復】 1. 重新檢查權限
            clipboardManager.loadItems() // 2. 載入
            // 【V7 耗電修復】 移除 checkClipboard()。此為最耗電的操作，
            // 移除後可大幅降低 App 返回前景時的 "背景" 電力消耗。
            // clipboardManager.checkClipboard() // 3. 檢查 (這會觸發 sortAndSave)
            
            // 【V7.1 耗電修Fix】 移除 cleanupItems()。
            // cleanupItems() 會在 init() 和 關閉設定時 執行，
            // 不需要每次返回前景都執行，這也會觸發 sort/save/update，造成耗電。
            // clipboardManager.cleanupItems() // 4. 清理
            
            // 5. syncActivityState 會在 checkActivityStatus() 確認權限後才執行
        }
        // 【功能修改】 使用 .onChange 處理非同步的開關
        .onChange(of: clipboardManager.isLiveActivityOn) {
            Task {
                if clipboardManager.isLiveActivityOn {
                    await clipboardManager.startActivity()
                } else {
                    await clipboardManager.endActivity()
                }
            }
        }
        // 【新功能】 當主題顏色改變時，立刻更新動態島
        .onChange(of: themeColorName) { newColor in // 【V4 修復】 捕捉新顏色
            if clipboardManager.isLiveActivityOn {
                // 【V4 修復】 將新顏色直接傳遞過去 (修復白色主題BUG)
                clipboardManager.updateActivity(newColorName: newColor)
            }
        }
    }
    
    // 【V2 錯誤修正】 這是列表 (List)
    private var listContent: some View {
        List {
            // 【錯誤修正】 步驟 3: 使用新的 ClipboardItemRow 子視圖
            ForEach(clipboardManager.items) { item in
                ClipboardItemRow(
                    item: item,
                    themeColor: themeColor,
                    copyAction: {
                        copyItemToClipboard(item: item)
                    },
                    previewAction: {
                        // 載入檔案資料以供預覽
                        var previewItem = item
                        if let filename = item.filename {
                            previewItem.fileData = clipboardManager.loadFileData(filename: filename)
                        }
                        selectedItem = previewItem
                    },
                    createDragItem: {
                        createDragItem(for: item)
                    },
                    togglePinAction: {
                        clipboardManager.togglePin(for: item)
                    },
                    deleteAction: {
                        if let index = clipboardManager.items.firstIndex(where: { $0.id == item.id }) {
                            deleteItems(at: IndexSet(integer: index))
                        }
                    },
                    renameAction: {
                        itemToRename = item
                        // 【V3 修復】 更名時優先使用 displayName
                        newName = item.displayName ?? item.content
                        isShowingRenameAlert = true // 【V3 修復】 觸發 Alert
                    },
                    shareAction: {
                        shareItem(item: item)
                    }
                )
            }
            .onDelete(perform: deleteItems) // 刪除邏輯 (for Edit mode)
        }
        .listStyle(.insetGrouped) // 【UI 優化】
        // 【新功能】 接收從其他 App 拖曳進來的項目
        .onDrop(of: [UTType.item], isTargeted: nil) { providers in
            clipboardManager.handleDroppedProviders(providers)
            return true // 表示已成功處理
        }
        .navigationTitle(Text("APP_NAME")) // 【本地化】 使用 KEY
        .toolbar {
            // 【功能修改】 改為單一按鈕，綠色開/紅色關
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // 觸發狀態切換
                    clipboardManager.isLiveActivityOn.toggle()
                }) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 14)) // 【UI 修改】 按鈕加大
                        .foregroundColor(clipboardManager.isLiveActivityOn ? .green : .red) // 開啟時綠色，關閉時紅色
                }
                .disabled(!activitiesEnabled) // 權限不足時禁用
                // 【UI 修改】 移除 padding
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                // 【新功能】 設定按鈕
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }


    // MARK: - 輔助函式 (Helper Functions)

    // 【新功能】 點擊圖示複製
    func copyItemToClipboard(item: ClipboardItem) {
        // 【V3 修復】 複製時永遠使用 content (原始 URL)
        if item.type == UTType.png.identifier, let filename = item.filename, let data = clipboardManager.loadFileData(filename: filename), let uiImage = UIImage(data: data) {
            // 複製圖片
            UIPasteboard.general.image = uiImage
        } else if item.type == UTType.url.identifier {
            // 複製 URL
            UIPasteboard.general.string = item.content
        } else if item.type == UTType.text.identifier {
            // 複製純文字
            UIPasteboard.general.string = item.content
        } else if let filename = item.filename, let data = clipboardManager.loadFileData(filename: filename) {
            // 複製其他檔案 (例如 PDF)
            UIPasteboard.general.setData(data, forPasteboardType: item.type)
        } else {
            // 備用：複製文字內容
             UIPasteboard.general.string = item.content
        }

        // 播放一個輕微的震動回饋
        AudioServicesPlaySystemSound(1519) // "Peek"
    }


    // 【新功能】 檢查動態島權限
    func checkActivityStatus() {
        Task {
            let info = ActivityAuthorizationInfo()
            let enabled = info.areActivitiesEnabled

            DispatchQueue.main.async {
                self.activitiesEnabled = enabled
                if !enabled {
                    print("❌ [偵錯] 動態島權限未開啟。")
                    // 【穩定性修復】 如果權限未開啟，強制關閉 App 內的開關
                    if clipboardManager.isLiveActivityOn {
                        clipboardManager.isLiveActivityOn = false
                        UserDefaults.standard.set(false, forKey: "isLiveActivityOn")
                    }
                } else {
                    print("✅ [偵錯] 動態島權限已開啟。")
                    // 【穩定性修復】 只有在權限開啟時，才同步狀態
                    clipboardManager.syncActivityState()
                }
            }
        }
    }

    // 【新功能】 分享功能
    func shareItem(item: ClipboardItem) {
        var itemsToShare: [Any] = []

        // 【V3 修復】 分享時永遠使用 content (原始 URL / 檔案)
        if let filename = item.filename, let data = clipboardManager.loadFileData(filename: filename) {
            // 如果是檔案，分享檔案資料
            itemsToShare.append(data)
        } else if item.type == UTType.url.identifier, let url = URL(string: item.content) {
            // 如果是 URL，分享 URL
            itemsToShare.append(url)
        } else {
            // 否則分享純文字
            itemsToShare.append(item.content)
        }

        guard !itemsToShare.isEmpty,
              // 【修復】 棄用 .windows，改用新的 UIWindowScene API
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sourceView = windowScene.windows.first?.rootViewController?.view
        else { return }

        let activityVC = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)

        // 適用於 iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = CGRect(x: sourceView.bounds.midX, y: sourceView.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        sourceView.window?.rootViewController?.present(activityVC, animated: true, completion: nil)
    }

    // 即時載入檔案資料的輔助函數
    func loadFileData(for item: ClipboardItem) -> Data? {
        if let filename = item.filename {
            return clipboardManager.loadFileData(filename: filename)
        }
        return nil
    }

    // 建立拖曳項目
    func createDragItem(for item: ClipboardItem) -> NSItemProvider {
        
        // 【V3 修復】 拖曳時永遠使用 content (原始 URL / 檔案)

        // 【修復 4】 提供多種格式 (UIImage 和 Data) 以最大化相容性
        if item.type == UTType.png.identifier,
           // 【修復】 移除多餘的 filename 檢查
           let data = loadFileData(for: item),
           let uiImage = UIImage(data: data) {

            // 1. 建立一個空的 provider
            let provider = NSItemProvider()

            // 2. 註冊 UIImage 物件 (LINE 喜歡這個)
            provider.registerObject(uiImage, visibility: .all)

            // 3. 註冊原始的 PNG 資料 (Teams 喜歡这个)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                // 【修復】 確保在主執行緒上呼叫 completion
                DispatchQueue.main.async {
                    completion(data, nil)
                }
                return nil // Return nil for Progress
            }
            return provider // Return the provider with multiple representations

        } else if item.type == UTType.url.identifier, let url = URL(string: item.content) {
            // Drag URL
            return NSItemProvider(object: url as NSURL)
        } else {
            // Drag text
            return NSItemProvider(object: item.content as NSString)
        }
    }

    // 刪除項目 (也刪除檔案)
    func deleteItems(at offsets: IndexSet) {
        let itemsToRemove = offsets.map { clipboardManager.items[$0] }

        // 刪除實體檔案
        for item in itemsToRemove {
            if let filename = item.filename, let containerURL = clipboardManager.getSharedContainerURL() {
                let fileURL = containerURL.appendingPathComponent(filename)
                do {
                    // 【修復】 透過 clipboardManager 存取 fileManager
                    try clipboardManager.fileManager.removeItem(at: fileURL)
                    print("✅ [偵錯] 成功刪除檔案: \(filename)")
                } catch {
                    print("❌ [偵錯] 刪除檔案 \(filename) 失敗: \(error.localizedDescription)")
                }
            }
        }

        // 從列表中移除
        clipboardManager.items.remove(atOffsets: offsets)
        // sortAndSave() 會被 @Published 自動觸發
    }
    
    // 【錯誤修正】
    // itemIcon(for:) 函式已被移到 ContentView 外部，
    // 所以這裡不再需要它了。
}

// SwiftUI 預覽 (僅在 Xcode 中使用)
#Preview {
    ContentView()
}







