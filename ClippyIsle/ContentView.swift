import SwiftUI
import ActivityKit
import UniformTypeIdentifiers
import Combine // 導入 Combine
import WebKit // 導入 WebKit
import AudioToolbox // 【新功能】 為了複製震動回饋

// MARK: - App Group 常數
let appGroupID = "group.com.shihchieh.clippyisle"

// MARK: - 【錯誤修正】 將 saveFileData 移出 MainActor
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
                WebView(urlString: item.content)
            } else {
                // 【V3 修復】 使用 UITextView (UIViewRepresentable)
                // 這將提供完整的原生選單 (拷貝、查詢、翻譯、朗讀) 並自動啟用網址
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
        ColorUtility.color(forName: themeColorName)
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
                    Text("App will automatically clean up old or redundant 'unpinned' items on each launch. If days and count are set to default, 30 days / 100 items will be applied.") // 【本地化】
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
                                    .foregroundColor(ColorUtility.color(forName: colorName))
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
                        Text("Done") // 【本地化】
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


// MARK: - 【新功能】 顏色管理
struct ColorUtility {
    static func color(forName name: String) -> Color {
        switch name.lowercased() {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "purple": return .purple
        // 【新功能】 新增黑色和白色
        case "black": return .black
        case "white": return .white
        default: return .blue
        }
    }
}

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
                Text(item.content)
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

    // 【新功能】 讀取主題顏色
    @AppStorage("themeColorName") private var themeColorName: String = "blue"
    // 【新功能】 讀取外觀模式
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue = AppearanceMode.system.rawValue

    var themeColor: Color {
        ColorUtility.color(forName: themeColorName)
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
                clipboardManager.updateActivity()
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
        .alert(Text("Rename Item"), isPresented: Binding(
            get: { itemToRename != nil },
            set: { if !$0 { itemToRename = nil } }
        )) {
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
            clipboardManager.checkClipboard() // 3. 檢查 (這會觸發 sortAndSave)
            clipboardManager.cleanupItems() // 4. 清理
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
        .onChange(of: themeColorName) {
            if clipboardManager.isLiveActivityOn {
                clipboardManager.updateActivity()
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
                        newName = item.content
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









