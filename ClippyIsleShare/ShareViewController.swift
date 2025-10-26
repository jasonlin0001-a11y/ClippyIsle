import UIKit
import Social
import UniformTypeIdentifiers
import SwiftUI

// MARK: - App Group 常數
// !!! 確保這與 ContentView.swift 中的 ID 完全一致
let appGroupID = "group.com.shihchieh.clippyisle"

// MARK: - 剪貼項目模型
// 【重大更新】 必須與 ContentView.swift 中的定義 "完全" 一致
struct ClipboardItem: Identifiable, Codable, Hashable {
    let id: UUID
    var content: String
    var type: String
    var filename: String? // 用於儲存大檔案的名稱
    var isPinned: Bool = false
    var timestamp: Date // 【新功能】 紀錄複製時間
    
    var fileData: Data? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, content, type, filename, isPinned, timestamp
    }
}

// MARK: - App Group 檔案管理器 (輔助)
class AppGroupFileManager {
    let fileManager = FileManager.default
    
    // 取得共享容器 URL
    func getSharedContainerURL() -> URL? {
        return fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    // 將資料寫入共享容器
    func saveFile(data: Data, type: String) -> String? {
        guard let containerURL = getSharedContainerURL() else {
            print("❌ [偵錯 Share] 儲存檔案失敗：無法取得共享容器 URL。")
            return nil
        }
        
        // 產生一個唯一的檔案名稱
        let id = UUID().uuidString
        let utType = UTType(type)
        let fileExtension = utType?.preferredFilenameExtension ?? "data"
        let filename = "\(id).\(fileExtension)"
        let fileURL = containerURL.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            print("✅ [偵錯 Share] 成功將檔案寫入: \(filename)")
            return filename
        } catch {
            print("❌ [偵錯 Share] 寫入檔案 \(filename) 失敗: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 簡易 SwiftUI 介面
struct ShareView: View {
    var onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Saved to Clippy Isle!") // 【本地化】
                .font(.title2)
            Button(action: onDone) {
                Text("Done") // 【本地化】
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
    }
}

// MARK: - 主要 View Controller
class ShareViewController: UIViewController {
    
    let fileManager = AppGroupFileManager()
    let userDefaults = UserDefaults(suiteName: appGroupID)

    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ [偵錯 Share] Share Extension 啟動。")
        
        // 顯示一個簡單的 "處理中" 介面
        let loadingView = UIActivityIndicatorView(style: .large)
        loadingView.center = self.view.center
        loadingView.startAnimating()
        self.view.addSubview(loadingView)

        // 開始處理分享的項目
        processSharedItems()
    }
    
    private func processSharedItems() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            // 【本地化】
            let error = NSError(domain: "ClippyIsleError", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("SHARE_ERROR_NOT_FOUND", comment: "Share error")])
            self.extensionContext?.cancelRequest(withError: error)
            return
        }
        print("ℹ️ [偵錯 Share] 找到 \(attachments.count) 個附件。")

        let group = DispatchGroup()
        var collectedItems: [ClipboardItem] = []

        for attachment in attachments {
            group.enter()
            
            // 優先處理 URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
                    if let url = item as? URL {
                        print("ℹ️ [偵錯 Share] 讀取到 URL: \(url.absoluteString)")
                        let newItem = ClipboardItem(id: UUID(), content: url.absoluteString, type: UTType.url.identifier, filename: nil, isPinned: false, timestamp: Date())
                        collectedItems.append(newItem)
                    }
                    group.leave()
                }
            }
            // 處理圖片
            else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                    var data: Data?
                    if let url = item as? URL {
                        data = try? Data(contentsOf: url)
                    } else if let image = item as? UIImage {
                        data = image.pngData() // 【修復】 確保我們用的是 PNG 資料
                    }
                    
                    if let fileData = data {
                        print("ℹ️ [偵錯 Share] 讀取到 Image (大小: \(fileData.count) bytes)")
                        // 【修復】 將大檔案寫為 PNG 類型
                        let filename = self.fileManager.saveFile(data: fileData, type: UTType.png.identifier)
                        // 【本地化】
                        let newItem = ClipboardItem(id: UUID(), content: NSLocalizedString("Image", comment: "Default name for image"), type: UTType.png.identifier, filename: filename, isPinned: false, timestamp: Date())
                        collectedItems.append(newItem)
                    }
                    group.leave()
                }
            }
            // 處理純文字
            else if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (item, error) in
                    if let text = item as? String {
                         print("ℹ️ [偵錯 Share] 讀取到 Text: \(text.prefix(50))...")
                        // 檢查文字是否其實是 URL
                        if let url = URL(string: text), (url.scheme == "http" || url.scheme == "https") {
                             let newItem = ClipboardItem(id: UUID(), content: text, type: UTType.url.identifier, filename: nil, isPinned: false, timestamp: Date())
                             collectedItems.append(newItem)
                        } else {
                            // 存為純文字
                             let newItem = ClipboardItem(id: UUID(), content: text, type: UTType.text.identifier, filename: nil, isPinned: false, timestamp: Date())
                             collectedItems.append(newItem)
                        }
                    }
                    group.leave()
                }
            }
            // 處理一般檔案 (PDF, etc.)
            else if attachment.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.data.identifier, options: nil) { (item, error) in
                    var data: Data?
                    var filename = NSLocalizedString("File", comment: "Default name for file") // 【本地化】
                    var type = UTType.data.identifier

                    if let url = item as? URL {
                        data = try? Data(contentsOf: url)
                        filename = url.lastPathComponent
                        if let uttype = UTType(filenameExtension: url.pathExtension) {
                            type = uttype.identifier
                        }
                    }
                    
                    if let fileData = data {
                         print("ℹ️ [偵錯 Share] 讀取到 File: \(filename) (大小: \(fileData.count) bytes)")
                        let savedFilename = self.fileManager.saveFile(data: fileData, type: type)
                        let newItem = ClipboardItem(id: UUID(), content: filename, type: type, filename: savedFilename, isPinned: false, timestamp: Date())
                        collectedItems.append(newItem)
                    }
                    group.leave()
                }
            } else {
                // 不支援的類型
                print("⚠️ [偵錯 Share] 找到不支援的類型。")
                group.leave()
            }
        }

        // 當所有項目都處理完畢
        group.notify(queue: .main) {
            print("ℹ️ [偵錯 Share] 所有附件處理完畢，準備儲存 \(collectedItems.count) 個項目。")
            self.saveToAppGroup(items: collectedItems)
            self.showDoneView()
        }
    }

    private func saveToAppGroup(items: [ClipboardItem]) {
        guard !items.isEmpty, let userDefaults = self.userDefaults else { return }

        // 【修復】 讀取現有項目
        var existingItems: [ClipboardItem] = []
        if let data = userDefaults.data(forKey: "clippedItems") {
            do {
                // 使用 *新結構* 來解碼
                existingItems = try JSONDecoder().decode([ClipboardItem].self, from: data)
                print("ℹ️ [偵錯 Share] 讀取到 \(existingItems.count) 個已儲存項目。")
            } catch {
                print("❌ [偵錯 Share] JSON 解碼失敗 (資料結構可能不同步): \(error)")
                // 如果解碼失敗，就忽略舊資料，避免 App 崩潰
                existingItems = []
            }
        } else {
             print("ℹ️ [偵錯 Share] 尚未有已儲存項目。")
        }
        
        // 將新項目加到最前面
        existingItems.insert(contentsOf: items, at: 0)

        // 寫回
        do {
            let encodedData = try JSONEncoder().encode(existingItems)
            userDefaults.set(encodedData, forKey: "clippedItems")
            print("✅ [偵錯 Share] 成功儲存 \(items.count) 個新項目到 App Group。總數: \(existingItems.count)")
        } catch {
             print("❌ [偵錯 Share] JSON 編碼失敗: \(error)")
        }
    }
    
    // 顯示完成的 SwiftUI 視圖
    private func showDoneView() {
        // 移除 loading view
        self.view.subviews.forEach { $0.removeFromSuperview() }
        
        let shareView = ShareView {
            // 點擊 "完成" 按鈕時，關閉 Share Extension
            print("ℹ️ [偵錯 Share] 使用者點擊 '完成'。")
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.frame = self.view.bounds
        self.view.addSubview(hostingController.view)
        self.addChild(hostingController)
        hostingController.didMove(toParent: self)
    }
}


